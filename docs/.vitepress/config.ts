import { defineConfig } from 'vitepress'

export default defineConfig({
  title: 'ZMouse',
  description: 'A Windows input controller and automation library written in Zig',
  lang: 'en-US',

  base: '/zmouse/',

  head: [
    ['link', { rel: 'icon', type: 'image/svg+xml', href: '/logo.svg' }]
  ],

  themeConfig: {
    logo: '/logo.svg',

    nav: [
      { text: 'Home', link: '/' },
      { text: 'Guide', link: '/guide/getting-started' },
      { text: 'Library', link: '/guide/library' },
      { text: 'HTTP API', link: '/guide/api' }
    ],

    sidebar: {
      '/guide/': [
        {
          text: 'Getting Started',
          items: [
            { text: 'Installation', link: '/guide/getting-started' },
            { text: 'Basic Usage', link: '/guide/basic-usage' },
            { text: 'Commands', link: '/guide/commands' }
          ]
        },
        {
          text: 'Features',
          items: [
            { text: 'Recording & Playback', link: '/guide/recording' },
            { text: 'HTTP API', link: '/guide/api' },
            { text: 'Screenshots', link: '/guide/screenshots' }
          ]
        },
        {
          text: 'Library',
          items: [
            { text: 'Library Usage', link: '/guide/library' }
          ]
        },
        {
          text: 'Reference',
          items: [
            { text: 'API Endpoints', link: '/guide/api-endpoints' },
            { text: 'JSON Format', link: '/guide/json-format' },
            { text: 'Architecture', link: '/guide/architecture' }
          ]
        }
      ]
    },

    socialLinks: [
      { icon: 'github', link: 'https://github.com/shishtpal/zmouse' }
    ],

    footer: {
      message: 'Released under the MIT License.',
      copyright: 'Copyright © 2026-present'
    },

    search: {
      provider: 'local'
    },

    outline: {
      level: [2, 3]
    }
  }
})
