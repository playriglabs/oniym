"use client";

import { motion } from "framer-motion";
import { SearchBar } from "./SearchBar";

export function Hero() {
    return (
        <section className="min-h-screen flex flex-col items-center justify-center px-4">
            <div className="w-full max-w-2xl mx-auto text-center">
                {/* Headline */}
                <motion.h1
                    initial={{ opacity: 0, y: 12 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ duration: 0.5, ease: [0.16, 1, 0.3, 1] }}
                    className="text-3xl sm:text-5xl font-bold tracking-tight text-text-primary mb-5"
                >
                    Your multichain name
                </motion.h1>

                {/* Subheadline */}
                <motion.p
                    initial={{ opacity: 0, y: 12 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ duration: 0.5, delay: 0.07, ease: [0.16, 1, 0.3, 1] }}
                    className="text-sm text-text-secondary mb-8"
                >
                    Resolves your identity and name. One name for all your crypto addresses
                </motion.p>

                {/* Search Bar */}
                <motion.div
                    initial={{ opacity: 0, y: 12 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ duration: 0.5, delay: 0.14, ease: [0.16, 1, 0.3, 1] }}
                >
                    <SearchBar />
                </motion.div>
            </div>
        </section>
    );
}
