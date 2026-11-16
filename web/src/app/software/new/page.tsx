"use client";

import Link from "next/link";
import { SoftwareForm } from "../../../components/SoftwareForm";

export default function NewSoftwarePage() {
  return (
    <div className="max-w-6xl mx-auto">
      <Link
        href="/software"
        className="inline-flex items-center gap-2 text-sm text-gray-500 hover:text-gray-900 transition-colors mb-8 group"
      >
        <svg width="16" height="16" className="transition-transform group-hover:-translate-x-0.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
        </svg>
        Back to Software
      </Link>

      <h1 className="text-2xl font-semibold text-gray-900 dark:text-gray-100 tracking-tight mb-8">
        Add New Software
      </h1>

      <SoftwareForm mode="create" />
    </div>
  );
}
