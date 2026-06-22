#!/bin/sh
awslocal s3 mb s3://touchme-media || true
awslocal s3 mb s3://nearby-connect-media || true
awslocal s3api put-bucket-cors --bucket touchme-media --cors-configuration '{"CORSRules":[{"AllowedHeaders":["content-type"],"AllowedMethods":["PUT","GET"],"AllowedOrigins":["*"],"MaxAgeSeconds":300}]}'
awslocal s3api put-bucket-cors --bucket nearby-connect-media --cors-configuration '{"CORSRules":[{"AllowedHeaders":["content-type"],"AllowedMethods":["PUT","GET"],"AllowedOrigins":["*"],"MaxAgeSeconds":300}]}'
