import js from "@eslint/js";
import tseslint from "typescript-eslint";
import type { Linter } from "eslint";

const config: Linter.Config[] = [
    js.configs.recommended,
    ...tseslint.configs.strictTypeChecked,
    ...tseslint.configs.stylisticTypeChecked,
    {
        languageOptions: {
            parserOptions: {
                projectService: {
                    allowDefaultProject: [
                        "sdk/*.config.ts",
                        "docs/*.config.ts",
                        "react/*.config.ts",
                        "examples/node/index.ts",
                    ],
                },
                tsconfigRootDir: import.meta.dirname,
            },
        },
    },
    {
        rules: {
            "@typescript-eslint/consistent-type-imports": "off",
            "@typescript-eslint/strict-boolean-expressions": "off",
            "@typescript-eslint/no-unsafe-member-access": "off",
            "@typescript-eslint/no-unsafe-assignment": "off",
            "@typescript-eslint/no-unsafe-call": "off",
            "@typescript-eslint/no-import-type-side-effects": "error",
            "@typescript-eslint/explicit-function-return-type": [
                "error",
                { allowExpressions: true, allowHigherOrderFunctions: true },
            ],
            "@typescript-eslint/no-explicit-any": "error",
            "@typescript-eslint/no-unsafe-return": "error",
            "@typescript-eslint/no-unused-vars": [
                "error",
                { argsIgnorePattern: "^_", varsIgnorePattern: "^_" },
            ],
            "@typescript-eslint/prefer-nullish-coalescing": "error",
            "@typescript-eslint/prefer-optional-chain": "error",
        },
    },
    {
        files: ["indexer/src/**/*.ts"],
        rules: {
            "@typescript-eslint/explicit-function-return-type": "off",
            "@typescript-eslint/no-misused-promises": "off",
            "@typescript-eslint/no-unnecessary-condition": "off",
            "@typescript-eslint/no-unsafe-argument": "off",
        },
    },
    {
        files: ["web/src/**/*.{ts,tsx}"],
        rules: {
            "@typescript-eslint/explicit-function-return-type": "off",
            "@typescript-eslint/restrict-template-expressions": "off",
            "@typescript-eslint/no-unsafe-return": "off",
            "@typescript-eslint/no-unnecessary-type-assertion": "off",
            "@typescript-eslint/no-misused-promises": "off",
            "@typescript-eslint/no-unsafe-argument": "off",
            "@typescript-eslint/no-confusing-void-expression": "off",
            "@typescript-eslint/restrict-plus-operands": "off",
            "@typescript-eslint/no-deprecated": "off",
        },
    },
    {
        ignores: [
            "**/dist/**",
            "**/node_modules/**",
            "**/out/**",
            "**/cache/**",
            "contracts/lib/**",
            "web/next-env.d.ts",
            "web/.next/**",
            "web/*.config.cjs",
            "web/*.config.js",
        ],
    },
];

export default config;
