/** @type {import('next').NextConfig} */
const nextConfig = {
  webpack: (config) => {
    config.resolve.alias.canvas = false;

    return config;
  },
  images: {
    remotePatterns: [
      {
        protocol: "https",
        hostname: "**",
      },
    ],
  },

  env: {
    BASE_PATH: "ProxmoxVE",
  },

  eslint: {
    ignoreDuringBuilds: true,
  },

  output: "export",
  // GitHub Pages cannot serve /scripts when both scripts.html and a scripts/ directory
  // exist, so every page is exported as <route>/index.html.
  trailingSlash: true,
  basePath: `/ProxmoxVE`,
};

export default nextConfig;
