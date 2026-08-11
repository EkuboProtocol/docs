// @ts-check
import sitemap from "@astrojs/sitemap";
import starlight from "@astrojs/starlight";
import { defineConfig } from "astro/config";
import starlightLlmsTxt from "starlight-llms-txt";
import starlightOpenAPI, { createOpenAPISidebarGroup } from "starlight-openapi";

const apiReferenceGroup = createOpenAPISidebarGroup();

export default defineConfig({
  site: "https://docs.ekubo.org",
  output: "static",
  trailingSlash: "always",
  integrations: [
    sitemap(),
    starlight({
      title: "Ekubo Docs",
      description:
        "Documentation for Ekubo Protocol users, integrators, and developers.",
      favicon: "/favicon.svg",
      logo: {
        src: "./public/logo.svg",
        replacesTitle: false,
      },
      customCss: ["./src/styles/custom.css"],
      editLink: {
        baseUrl: "https://github.com/EkuboProtocol/docs/edit/main/",
      },
      head: [
        { tag: "meta", attrs: { name: "theme-color", content: "#f23d30" } },
        {
          tag: "link",
          attrs: {
            rel: "alternate",
            type: "text/plain",
            href: "/llms.txt",
            title: "LLM documentation index",
          },
        },
        {
          tag: "script",
          content: `document.addEventListener("DOMContentLoaded", () => {
            for (const element of document.querySelectorAll("pre, table")) {
              if (element.scrollWidth > element.clientWidth) element.tabIndex = 0;
            }
          });`,
        },
      ],
      social: [
        {
          icon: "github",
          label: "GitHub",
          href: "https://github.com/EkuboProtocol",
        },
        {
          icon: "discord",
          label: "Discord",
          href: "https://discord.ekubo.org",
        },
        { icon: "x.com", label: "X", href: "https://x.com/EkuboProtocol" },
      ],
      plugins: [
        starlightLlmsTxt({
          projectName: "Ekubo Protocol",
          description:
            "Documentation for using and integrating Ekubo Protocol.",
          details:
            "Static endpoint reference pages are generated from the live OpenAPI specifications on every build.",
          optionalLinks: [
            {
              label: "Ekubo API OpenAPI 3.1",
              url: "https://docs.ekubo.org/openapi/ekubo.json",
              description:
                "Machine-readable snapshot used to generate the API reference",
            },
            {
              label: "Quoter API OpenAPI 3.1",
              url: "https://docs.ekubo.org/openapi/quoter.json",
              description:
                "Machine-readable snapshot used to generate the quoter reference",
            },
            {
              label: "Generated API reference",
              url: "https://docs.ekubo.org/api/ekubo/",
              description: "Static, indexable endpoint documentation",
            },
          ],
        }),
        starlightOpenAPI([
          {
            base: "api/ekubo",
            schema: "./schemas/ekubo.json",
            sidebar: {
              label: "Ekubo API",
              group: apiReferenceGroup,
              collapsed: true,
              operations: { badges: true, labels: "summary" },
            },
          },
          {
            base: "api/quoter",
            schema: "./schemas/quoter.json",
            sidebar: {
              label: "Quoter API",
              group: apiReferenceGroup,
              collapsed: false,
              operations: { badges: true, labels: "summary" },
            },
          },
        ]),
      ],
      sidebar: [
        {
          label: "About Ekubo",
          items: [
            { label: "👋 Introduction", slug: "index" },
            { label: "🔑 Features", slug: "about-ekubo/features" },
            { label: "🔮 Vision", slug: "about-ekubo/vision" },
            { label: "📄 V3 Whitepaper", slug: "about-ekubo/v3-whitepaper" },
          ],
        },
        {
          label: "Products",
          items: [
            { label: "✨ Overview", slug: "products" },
            { label: "🔄 Trading", slug: "products/trading" },
            { label: "🌊 Providing liquidity", slug: "products/liquidity" },
            { label: "🗳️ Ve33 and STONX", slug: "products/ve33" },
            { label: "🎁 Rewards and incentives", slug: "products/rewards" },
            { label: "🗄️ Indexer", slug: "products/indexer" },
            { label: "🤖 MCP server", slug: "products/mcp-server" },
            { label: "🏩 Governance", slug: "products/governance" },
          ],
        },
        {
          label: "Concepts",
          items: [
            { label: "🧠 Key concepts", slug: "concepts/key-concepts" },
            {
              label: "🏛️ Protocol architecture",
              slug: "concepts/architecture",
            },
            {
              label: "🔌 Extensions",
              slug: "concepts/extensions",
              items: [
                {
                  label: "Compared to Uniswap v4 hooks",
                  slug: "concepts/extensions-vs-v4-hooks",
                },
              ],
            },
          ],
        },
        {
          label: "User Guides",
          items: [
            { label: "🌊 Add liquidity", slug: "user-guides/add-liquidity" },
            {
              label: "⌛ Dollar-cost average orders",
              slug: "user-guides/dollar-cost-average-orders",
            },
            { label: "🪙 EKUBO token", slug: "user-guides/ekubo-token" },
            {
              label: "🏛️ Participate in governance",
              slug: "user-guides/governance",
            },
          ],
        },
        {
          label: "Integration Guides",
          items: [
            { label: "🧩 Integrating Ekubo", slug: "integration-guides" },
            { label: "📦 SDKs", slug: "integration-guides/sdks" },
            { label: "🔄 Swapping", slug: "integration-guides/swapping" },
            { label: "⚡ Yul Router", slug: "integration-guides/yul-router" },
            { label: "🧭 Aggregators", slug: "integration-guides/aggregators" },
            {
              label: "✍️ Signed exclusive swaps",
              slug: "integration-guides/signed-exclusive-swaps",
            },
            {
              label: "📖 Reading pool price",
              slug: "integration-guides/reading-pool-price",
            },
          ],
        },
        {
          label: "Reference",
          items: [
            { label: "🧮 Pool math", slug: "reference/pool-math" },
            {
              label: "💹 Price representation",
              slug: "reference/price-representation",
            },
            {
              label: "📜 Contract addresses",
              slug: "reference/contracts",
              items: [
                { label: "EVM (V3)", slug: "reference/contracts/evm-v3" },
                { label: "Starknet", slug: "reference/contracts/starknet" },
                { label: "Governance", slug: "reference/contracts/governance" },
                {
                  label: "EVM (V2, deprecated)",
                  slug: "reference/contracts/evm-v2",
                },
              ],
            },
            { label: "🌐 Ekubo API", slug: "reference/ekubo-api" },
            { label: "🧮 Quoter API", slug: "reference/quoter-api" },
            apiReferenceGroup,
            {
              label: "🧪 API Explorers",
              items: [
                { label: "Ekubo API", link: "/api-explorer/ekubo/" },
                { label: "Quoter API", link: "/api-explorer/quoter/" },
              ],
            },
            { label: "🛡️ Audits", slug: "reference/audits" },
          ],
        },
        {
          label: "Links",
          items: [
            { label: "Home", link: "https://ekubo.org" },
            { label: "Blog", link: "https://blog.ekubo.org" },
            { label: "Discord", link: "https://discord.ekubo.org" },
          ],
        },
      ],
    }),
  ],
});
