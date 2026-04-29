/* eslint-disable @typescript-eslint/explicit-function-return-type */
import { Header } from "@/components/layout/Header";
import { Hero } from "@/components/hero/Hero";

export default function HomePage() {
    return (
        <>
            <Header />
            <main>
                <Hero />
            </main>
        </>
    );
}
