import { Injectable, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import nodemailer, { Transporter } from 'nodemailer';

@Injectable()
export class CommunicationsService {
  private readonly transporter?: Transporter;
  constructor(private readonly config: ConfigService) {
    const host = config.get<string>('SMTP_HOST');
    if (host) this.transporter = nodemailer.createTransport({ host, port: config.get<number>('SMTP_PORT', 587), secure: config.get<number>('SMTP_PORT', 587) === 465, auth: { user: config.get('SMTP_USER'), pass: config.get('SMTP_PASSWORD') } });
  }
  async sendPasswordReset(email: string, token: string): Promise<void> {
    await this.send(email, 'Reset your TouchMe password', `Use this one-time reset token in TouchMe: ${token}\n\nIt expires in 30 minutes. If you did not request this, ignore this message.`);
  }
  async sendEmailVerification(email: string, token: string): Promise<void> {
    await this.send(email, 'Verify your TouchMe email', `Use this one-time verification token in TouchMe: ${token}\n\nIt expires in 30 minutes.`);
  }

  async sendSms(phone: string, message: string): Promise<void> {
    const accountSid = this.config.get<string>('TWILIO_ACCOUNT_SID');
    const authToken = this.config.get<string>('TWILIO_AUTH_TOKEN');
    const from = this.config.get<string>('TWILIO_FROM_NUMBER');
    if (!accountSid || !authToken || !from) {
      if (this.config.get('NODE_ENV') === 'production') {
        throw new ServiceUnavailableException('SMS provider unavailable');
      }
      return;
    }
    const response = await fetch(
      `https://api.twilio.com/2010-04-01/Accounts/${accountSid}/Messages.json`,
      {
        method: 'POST',
        headers: {
          Authorization: `Basic ${Buffer.from(`${accountSid}:${authToken}`).toString('base64')}`,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: new URLSearchParams({ To: phone, From: from, Body: message }),
      },
    );
    if (!response.ok) throw new ServiceUnavailableException('SMS delivery failed');
  }

  private async send(to: string, subject: string, text: string): Promise<void> {
    if (!this.transporter) {
      if (this.config.get('NODE_ENV') === 'production') throw new ServiceUnavailableException('Email provider unavailable');
      return;
    }
    await this.transporter.sendMail({ from: this.config.get('SMTP_FROM', 'TouchMe <no-reply@touchme.app>'), to, subject, text });
  }
}
