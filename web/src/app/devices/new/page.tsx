"use client";

import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { Suspense } from "react";
import { DeviceForm } from "../../../components/DeviceForm";

function NewDeviceFormWithParams() {
    const searchParams = useSearchParams();

    const prefill: Record<string, any> = {};
    if (searchParams.get("name")) prefill.name = searchParams.get("name")!;
    if (searchParams.get("additionalName")) prefill.additionalName = searchParams.get("additionalName")!;
    if (searchParams.get("manufacturer")) prefill.manufacturer = searchParams.get("manufacturer")!;
    if (searchParams.get("modelNumber")) prefill.modelNumber = searchParams.get("modelNumber")!;
    if (searchParams.get("releaseYear")) {
        const year = parseInt(searchParams.get("releaseYear")!, 10);
        if (!isNaN(year)) prefill.releaseYear = year;
    }
    if (searchParams.get("categoryId")) {
        const catId = parseInt(searchParams.get("categoryId")!, 10);
        if (!isNaN(catId)) prefill.categoryId = catId;
    }
    if (searchParams.get("cpuType")) prefill.cpuType = searchParams.get("cpuType")!;
    if (searchParams.get("cpuSpeed")) prefill.cpuSpeed = searchParams.get("cpuSpeed")!;
    if (searchParams.get("ram")) prefill.ram = searchParams.get("ram")!;
    if (searchParams.get("graphicsChip")) prefill.graphicsChip = searchParams.get("graphicsChip")!;
    if (searchParams.get("screenSize")) prefill.screenSize = searchParams.get("screenSize")!;
    if (searchParams.get("displayType")) prefill.displayType = searchParams.get("displayType")!;
    if (searchParams.get("displayVariant")) prefill.displayVariant = searchParams.get("displayVariant")!;
    if (searchParams.get("nativeResolution")) prefill.nativeResolution = searchParams.get("nativeResolution")!;
    if (searchParams.get("storage")) prefill.storage = searchParams.get("storage")!;
    if (searchParams.get("operatingSystem")) prefill.operatingSystem = searchParams.get("operatingSystem")!;
    if (searchParams.get("externalUrl")) prefill.externalUrl = searchParams.get("externalUrl")!;
    if (searchParams.get("serialNumber")) prefill.serialNumber = searchParams.get("serialNumber")!;
    if (searchParams.get("templateId")) {
        const tplId = parseInt(searchParams.get("templateId")!, 10);
        if (!isNaN(tplId)) prefill.templateId = tplId;
    }
    if (searchParams.get("isWifiEnabled")) prefill.isWifiEnabled = true;
    if (searchParams.get("pramBatteryInstalled")) prefill.pramBatteryInstalled = searchParams.get("pramBatteryInstalled") === "1";

    return <DeviceForm mode="create" prefill={prefill} />;
}

export default function NewDevicePage() {
    return (
        <div className="max-w-6xl mx-auto">
            <Link
                href="/"
                className="inline-flex items-center gap-2 text-sm text-gray-500 hover:text-gray-900 transition-colors mb-8 group"
            >
                <svg width="16" height="16" className="transition-transform group-hover:-translate-x-0.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
                </svg>
                Back to Inventory
            </Link>

            <h1 className="text-2xl font-semibold text-gray-900 dark:text-gray-100 tracking-tight mb-8">
                Add New Device
            </h1>

            <Suspense fallback={<div className="text-sm text-gray-500">Loading form…</div>}>
                <NewDeviceFormWithParams />
            </Suspense>
        </div>
    );
}
