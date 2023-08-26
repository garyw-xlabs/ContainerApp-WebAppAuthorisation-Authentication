/* eslint-disable @typescript-eslint/no-var-requires */
const withBundleAnalyzer = require('@next/bundle-analyzer')({
    enabled: process.env.ANALYZE === 'true',
  });
  
  /** @type {import('next').NextConfig} */
  const nextConfig = {
    output: 'standalone',
  };
  
  module.exports = withBundleAnalyzer(nextConfig);
  