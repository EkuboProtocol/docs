// @ts-check
import sitemap from "@astrojs/sitemap";
import starlight from "@astrojs/starlight";
import { defineConfig } from "astro/config";
import starlightLlmsTxt from "starlight-llms-txt";

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
      customCss: ["./src/styles/fonts.css", "./src/styles/custom.css"],
      components: {
        SiteTitle: "./src/components/SiteTitle.astro",
        ThemeSelect: "./src/components/ThemeToggle.astro",
        Footer: "./src/components/Footer.astro",
      },
      editLink: {
        baseUrl: "https://github.com/EkuboProtocol/docs/edit/main/",
      },
      head: [
        { tag: "meta", attrs: { name: "theme-color", content: "#661cc4" } },
        {
          tag: "link",
          attrs: {
            rel: "preload",
            href: "/fonts/suisse-intl-400.f6cfafea4909.woff2",
            as: "font",
            type: "font/woff2",
            crossorigin: "anonymous",
          },
        },
        {
          tag: "link",
          attrs: {
            rel: "preload",
            href: "/fonts/suisse-intl-600.480cfa8f0417.woff2",
            as: "font",
            type: "font/woff2",
            crossorigin: "anonymous",
          },
        },
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
            const searchButton = document.querySelector('button[data-open-modal]');
            if (searchButton?.textContent?.trim()) {
              searchButton.setAttribute('aria-label', searchButton.textContent.trim());
            }
            for (const element of document.querySelectorAll("pre, table")) {
              if (element.scrollWidth > element.clientWidth) element.tabIndex = 0;
            }
            const asides = new Map();
            for (const aside of document.querySelectorAll(".starlight-aside[aria-label]")) {
              const label = aside.getAttribute("aria-label");
              if (!label) continue;
              const group = asides.get(label) ?? [];
              group.push(aside);
              asides.set(label, group);
            }
            for (const [label, group] of asides) {
              if (group.length < 2) continue;
              group.forEach((aside, index) => aside.setAttribute("aria-label", label + " " + (index + 1)));
            }
            const regions = new Map();
            for (const region of document.querySelectorAll('[role="region"]')) {
              const labelledBy = region.getAttribute("aria-labelledby");
              const label = region.getAttribute("aria-label") ||
                (labelledBy && document.getElementById(labelledBy)?.textContent?.trim());
              if (!label) continue;
              const group = regions.get(label) ?? [];
              group.push(region);
              regions.set(label, group);
            }
            for (const [label, group] of regions) {
              if (group.length < 2) continue;
              group.forEach((region, index) => {
                region.setAttribute("aria-label", label + " " + (index + 1));
                region.removeAttribute("aria-labelledby");
              });
            }
            const labelCodeRegions = () => {
              document.querySelectorAll("pre").forEach((region, index) => {
                region.setAttribute("aria-label", "Code example " + (index + 1));
                region.removeAttribute("aria-labelledby");
              });
            };
            labelCodeRegions();
            // Expressive Code adds overflow landmarks after DOMContentLoaded.
            // Label them once its layout work has completed as well.
            window.setTimeout(labelCodeRegions, 100);
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
            "The interactive API reference is generated from the live OpenAPI specifications on every build.",
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
              label: "Interactive API reference",
              url: "https://docs.ekubo.org/api/",
              description:
                "Search both APIs, inspect schemas and examples, and test requests",
            },
          ],
        }),
      ],
      sidebar: [
        {
          label: "About Ekubo",
          items: [
            { label: "Introduction", slug: "index" },
            { label: "Features", slug: "about-ekubo/features" },
            { label: "Vision", slug: "about-ekubo/vision" },
            { label: "V3 Whitepaper", slug: "about-ekubo/v3-whitepaper" },
          ],
        },
        {
          label: "Products",
          items: [
            { label: "Overview", slug: "products" },
            { label: "Trading", slug: "products/trading" },
            { label: "Providing liquidity", slug: "products/liquidity" },
            { label: "Ve33 and STONX", slug: "products/ve33" },
            { label: "Rewards and incentives", slug: "products/rewards" },
            { label: "Indexer", slug: "products/indexer" },
            { label: "MCP server", slug: "products/mcp-server" },
            { label: "Governance", slug: "products/governance" },
          ],
        },
        {
          label: "Wallet",
          items: [
            { label: "Overview", slug: "wallet" },
            { label: "Install", slug: "wallet/install" },
            { label: "AI agents", slug: "wallet/agents" },
            { label: "Supported protocols", slug: "wallet/protocols" },
            { label: "Review requests", slug: "wallet/approvals" },
            { label: "Signing policies", slug: "wallet/policies" },
            { label: "WalletConnect", slug: "wallet/walletconnect" },
            { label: "Security and privacy", slug: "wallet/security" },
          ],
        },
        {
          label: "Concepts",
          items: [
            { label: "Key concepts", slug: "concepts/key-concepts" },
            {
              label: "Protocol architecture",
              slug: "concepts/architecture",
            },
            {
              label: "Extensions",
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
            { label: "Add liquidity", slug: "user-guides/add-liquidity" },
            {
              label: "Dollar-cost average orders",
              slug: "user-guides/dollar-cost-average-orders",
            },
            { label: "EKUBO token", slug: "user-guides/ekubo-token" },
            {
              label: "Participate in governance",
              slug: "user-guides/governance",
            },
          ],
        },
        {
          label: "Integration Guides",
          items: [
            { label: "Integrating Ekubo", slug: "integration-guides" },
            { label: "SDKs", slug: "integration-guides/sdks" },
            { label: "Swapping", slug: "integration-guides/swapping" },
            { label: "Yul Router", slug: "integration-guides/yul-router" },
            { label: "Aggregators", slug: "integration-guides/aggregators" },
            {
              label: "Signed exclusive swaps",
              slug: "integration-guides/signed-exclusive-swaps",
            },
            {
              label: "Reading pool price",
              slug: "integration-guides/reading-pool-price",
            },
          ],
        },
        {
          label: "Reference",
          items: [
            { label: "Pool math", slug: "reference/pool-math" },
            {
              label: "Price representation",
              slug: "reference/price-representation",
            },
            {
              label: "Contract addresses",
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
            {
              label: "API reference",
              link: "/api/",
            },
            { label: "Audits", slug: "reference/audits" },
          ],
        },
      ],
    }),
  ],
});
