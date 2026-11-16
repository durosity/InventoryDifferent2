"use client";

import { useMutation, useQuery, useApolloClient } from "@apollo/client";
import gql from "graphql-tag";
import { useRouter } from "next/navigation";
import { useState, useEffect, useMemo } from "react";
import { useT } from "../i18n/context";

const GET_CUSTOM_FIELDS = gql`
  query GetCustomFieldsSoftware {
    customFields {
      id
      name
      isPublic
      sortOrder
    }
  }
`;

const SET_CUSTOM_FIELD_VALUE = gql`
  mutation SetCustomFieldValueSoftware($input: SetCustomFieldValueInput!) {
    setCustomFieldValue(input: $input) {
      id
      customFieldId
      customFieldName
      value
      isPublic
    }
  }
`;

const REMOVE_CUSTOM_FIELD_VALUE = gql`
  mutation RemoveCustomFieldValueSoftware($deviceId: Int!, $customFieldId: Int!) {
    removeCustomFieldValue(deviceId: $deviceId, customFieldId: $customFieldId)
  }
`;

const ADD_DEVICE_ACCESSORY = gql`
  mutation AddDeviceAccessorySoftware($deviceId: Int!, $name: String!) {
    addDeviceAccessory(deviceId: $deviceId, name: $name) {
      id
      name
    }
  }
`;

const REMOVE_DEVICE_ACCESSORY = gql`
  mutation RemoveDeviceAccessorySoftware($id: Int!) {
    removeDeviceAccessory(id: $id)
  }
`;

const ADD_DEVICE_LINK = gql`
  mutation AddDeviceLinkSoftware($deviceId: Int!, $label: String!, $url: String!) {
    addDeviceLink(deviceId: $deviceId, label: $label, url: $url) {
      id
      label
      url
    }
  }
`;

const REMOVE_DEVICE_LINK = gql`
  mutation RemoveDeviceLinkSoftware($id: Int!) {
    removeDeviceLink(id: $id)
  }
`;

const GET_CATEGORIES = gql`
  query GetCategoriesSoftwareForm {
    categories {
      id
      name
      type
      showSoftwareFields
      parentId
      sortOrder
    }
  }
`;

const GET_LOCATIONS = gql`
  query GetLocationsForSoftwareForm {
    locations {
      id
      name
    }
  }
`;

const CREATE_LOCATION_INLINE = gql`
  mutation CreateLocationInlineSoftware($name: String!) {
    createLocation(name: $name) {
      id
      name
    }
  }
`;

// Local Templates whose category is flagged for software — the Macintosh Garden
// search/prefill integration is a planned follow-up; this reuses the existing
// Template catalog for now so the search box isn't dead on arrival.
const GET_TEMPLATES = gql`
  query GetTemplatesSoftwareForm {
    templates {
      id
      name
      additionalName
      manufacturer
      modelNumber
      releaseYear
      estimatedValue
      rarity
      historicalNotes
      externalUrl
      externalLinkLabel
      categoryId
    }
  }
`;

const CREATE_DEVICE = gql`
  mutation CreateDeviceSoftware($input: DeviceCreateInput!) {
    createDevice(input: $input) {
      id
    }
  }
`;

const UPDATE_DEVICE = gql`
  mutation UpdateDeviceSoftware($input: DeviceUpdateInput!) {
    updateDevice(input: $input) {
      id
      name
      additionalName
      manufacturer
      modelNumber
      serialNumber
      releaseYear
      location { id name }
      info
      isFavorite
      externalUrl
      status
      condition
      rarity
      isAssetTagged
      dateAcquired
      whereAcquired
      priceAcquired
      estimatedValue
      listPrice
      soldPrice
      soldDate
      historicalNotes
      platform
      licenceKey
      requiresDongle
      downloadUrl
      localPath
      hasOriginalManuals
      category { id name type showSoftwareFields }
    }
  }
`;

interface Category {
  id: number;
  name: string;
  type: string;
  showSoftwareFields: boolean;
  parentId: number | null;
  sortOrder: number;
}

interface Template {
  id: number;
  name: string;
  additionalName?: string;
  manufacturer?: string;
  modelNumber?: string;
  releaseYear?: number;
  estimatedValue?: number;
  rarity?: string;
  historicalNotes?: string;
  externalUrl?: string;
  externalLinkLabel?: string;
  categoryId: number;
}

interface SoftwareAccessory {
  id: number;
  name: string;
}

interface SoftwareLink {
  id: number;
  label: string;
  url: string;
}

interface SoftwareData {
  id: number;
  name: string;
  additionalName?: string;
  manufacturer: string;
  modelNumber: string;
  serialNumber: string;
  releaseYear: number;
  location: { id: number; name: string } | null;
  info?: string;
  historicalNotes?: string;
  isFavorite: boolean;
  externalUrl?: string;
  status: string;
  condition?: string;
  rarity?: string;
  isAssetTagged: boolean;
  dateAcquired?: string;
  whereAcquired?: string;
  priceAcquired?: number;
  estimatedValue?: number;
  listPrice?: number;
  soldPrice?: number;
  soldDate?: string;
  platform?: string;
  licenceKey?: string;
  requiresDongle?: boolean;
  downloadUrl?: string;
  localPath?: string;
  hasOriginalManuals?: boolean;
  accessories?: SoftwareAccessory[];
  links?: SoftwareLink[];
  category: { id: number; type: string; showSoftwareFields: boolean };
  customFieldValues?: {
    id: number;
    customFieldId: number;
    customFieldName: string;
    value: string;
    isPublic: boolean;
  }[];
}

interface SoftwareFormProps {
  software?: SoftwareData;
  mode: "create" | "edit";
}

function SectionHeader({ children }: { children: React.ReactNode }) {
  return (
    <h3 className="text-xs font-semibold text-[var(--muted-foreground)] uppercase tracking-wider mb-4 mt-8 first:mt-0">
      {children}
    </h3>
  );
}

function FormField({ label, required, children }: { label: string; required?: boolean; children: React.ReactNode }) {
  return (
    <div>
      <label className="block text-sm font-medium text-[var(--muted-foreground)] mb-1">
        {label}
        {required && <span className="text-[var(--apple-red)] ml-1">*</span>}
      </label>
      {children}
    </div>
  );
}

const inputClass = "input-retro w-full px-3 py-2 text-sm text-[var(--foreground)]";
const selectClass = "select-flat w-full px-4 py-2 text-sm text-[var(--foreground)]";

const getLocalDateInputValue = () => {
  const d = new Date();
  const tzOffsetMs = d.getTimezoneOffset() * 60 * 1000;
  return new Date(d.getTime() - tzOffsetMs).toISOString().slice(0, 10);
};

// Builds a flat, indented option list for a hierarchical category tree —
// top level first, each followed immediately by its children.
function buildCategoryOptions(categories: Category[]): (Category & { depth: number })[] {
  const byParent = new Map<number | null, Category[]>();
  for (const cat of categories) {
    const key = cat.parentId && categories.some((c) => c.id === cat.parentId) ? cat.parentId : null;
    if (!byParent.has(key)) byParent.set(key, []);
    byParent.get(key)!.push(cat);
  }
  for (const list of byParent.values()) {
    list.sort((a, b) => a.sortOrder - b.sortOrder || a.name.localeCompare(b.name));
  }
  const result: (Category & { depth: number })[] = [];
  const walk = (parentId: number | null, depth: number) => {
    for (const cat of byParent.get(parentId) ?? []) {
      result.push({ ...cat, depth });
      walk(cat.id, depth + 1);
    }
  };
  walk(null, 0);
  return result;
}

const softwareAccessorySuggestions = ["Original Box", "Manual", "Registration Card", "Key Card", "Floppy Disks", "CD/DVD", "Dongle"];

interface MacintoshRepoSearchResult {
  name: string;
  url: string;
  year?: number;
  sectionLabel: "Applications" | "Games";
}

interface MacintoshRepoDetails {
  name: string;
  url: string;
  author?: string;
  type?: string;
  category?: string;
  categories?: string[];
  year?: number;
}

function authHeaders(): HeadersInit {
  const token = typeof window !== "undefined" ? localStorage.getItem("inv_access_token") : null;
  return token ? { Authorization: `Bearer ${token}` } : {};
}

export function SoftwareForm({ software, mode }: SoftwareFormProps) {
  const t = useT();
  const router = useRouter();
  const apolloClient = useApolloClient();
  const { data: categoriesData } = useQuery(GET_CATEGORIES);
  const { data: locationsData, refetch: refetchLocations } = useQuery(GET_LOCATIONS);
  const { data: templatesData } = useQuery(GET_TEMPLATES);
  const { data: customFieldsData } = useQuery(GET_CUSTOM_FIELDS);
  const [createLocationInline] = useMutation(CREATE_LOCATION_INLINE);
  const [createDevice, { loading: creating }] = useMutation(CREATE_DEVICE);
  const [updateDevice, { loading: updating }] = useMutation(UPDATE_DEVICE);
  const [setCustomFieldValue] = useMutation(SET_CUSTOM_FIELD_VALUE);
  const [removeCustomFieldValue] = useMutation(REMOVE_CUSTOM_FIELD_VALUE);
  const [addDeviceAccessory] = useMutation(ADD_DEVICE_ACCESSORY);
  const [removeDeviceAccessory] = useMutation(REMOVE_DEVICE_ACCESSORY);
  const [addDeviceLink] = useMutation(ADD_DEVICE_LINK);
  const [removeDeviceLink] = useMutation(REMOVE_DEVICE_LINK);

  const allCategories: Category[] = categoriesData?.categories ?? [];
  const softwareCategories = useMemo(
    () => buildCategoryOptions(allCategories.filter((c) => c.showSoftwareFields)),
    [allCategories]
  );

  const [formData, setFormData] = useState({
    name: "",
    additionalName: "",
    manufacturer: "", // Publisher
    modelNumber: "",  // Version
    releaseYear: new Date().getFullYear(),
    locationId: 0 as number,
    categoryId: softwareCategories[0]?.id ?? 0,
    platform: "",
    licenceKey: "",
    requiresDongle: false,
    downloadUrl: "",
    localPath: "",
    hasOriginalManuals: false,
    info: "",
    historicalNotes: "",
    isFavorite: false,
    isAssetTagged: false,
    externalUrl: "",
    status: "COLLECTION",
    condition: "" as string,
    rarity: "" as string,
    dateAcquired: getLocalDateInputValue(),
    whereAcquired: "",
    priceAcquired: "",
    estimatedValue: "",
    listPrice: "",
    soldPrice: "",
    soldDate: "",
  });

  const [customFieldFormValues, setCustomFieldFormValues] = useState<Record<number, string>>({});
  const [selectedTemplateId, setSelectedTemplateId] = useState<number>(0);
  const [templateQuery, setTemplateQuery] = useState<string>("");
  const [errors, setErrors] = useState<Record<string, string>>({});

  const [mrResults, setMrResults] = useState<MacintoshRepoSearchResult[]>([]);
  const [mrLoading, setMrLoading] = useState(false);
  const [mrSelectedUrl, setMrSelectedUrl] = useState<string | null>(null);
  const [mrApplying, setMrApplying] = useState(false);

  const [accessories, setAccessories] = useState<Array<{ id?: number; name: string }>>(
    software?.accessories?.map((a) => ({ id: a.id, name: a.name })) ?? []
  );
  const [newAccessoryName, setNewAccessoryName] = useState("");

  const [links, setLinks] = useState<Array<{ id?: number; label: string; url: string }>>(
    software?.links?.map((l) => ({ id: l.id, label: l.label, url: l.url })) ?? []
  );
  const [newLinkLabel, setNewLinkLabel] = useState("");
  const [newLinkUrl, setNewLinkUrl] = useState("");

  // Once categories load, default the picker to the first software category if nothing selected yet
  useEffect(() => {
    if (mode === "create" && formData.categoryId === 0 && softwareCategories.length > 0) {
      setFormData((prev) => ({ ...prev, categoryId: softwareCategories[0].id }));
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [softwareCategories.length]);

  // Debounced live search against Macintosh Repository
  useEffect(() => {
    const q = templateQuery.trim();
    if (mode !== "create" || q.length < 2) {
      setMrResults([]);
      return;
    }
    let cancelled = false;
    setMrLoading(true);
    const timer = setTimeout(async () => {
      try {
        const res = await fetch(`/software-lookup/search?q=${encodeURIComponent(q)}`, { headers: authHeaders() });
        if (!res.ok) throw new Error("search failed");
        const data = await res.json();
        if (!cancelled) setMrResults(data.results ?? []);
      } catch {
        if (!cancelled) setMrResults([]);
      } finally {
        if (!cancelled) setMrLoading(false);
      }
    }, 400);
    return () => { cancelled = true; clearTimeout(timer); };
  }, [templateQuery, mode]);

  useEffect(() => {
    if (software && mode === "edit") {
      setFormData({
        name: software.name || "",
        additionalName: software.additionalName || "",
        manufacturer: software.manufacturer || "",
        modelNumber: software.modelNumber || "",
        releaseYear: software.releaseYear || new Date().getFullYear(),
        locationId: software.location?.id ?? 0,
        categoryId: software.category?.id || 0,
        platform: software.platform || "",
        licenceKey: software.licenceKey || "",
        requiresDongle: software.requiresDongle || false,
        downloadUrl: software.downloadUrl || "",
        localPath: software.localPath || "",
        hasOriginalManuals: software.hasOriginalManuals || false,
        info: software.info || "",
        historicalNotes: software.historicalNotes || "",
        isFavorite: software.isFavorite || false,
        isAssetTagged: software.isAssetTagged || false,
        externalUrl: software.externalUrl || "",
        status: software.status || "COLLECTION",
        condition: software.condition || "",
        rarity: software.rarity || "",
        dateAcquired: software.dateAcquired ? software.dateAcquired.split("T")[0] : "",
        whereAcquired: software.whereAcquired || "",
        priceAcquired: software.priceAcquired?.toString() || "",
        estimatedValue: software.estimatedValue?.toString() || "",
        listPrice: software.listPrice?.toString() || "",
        soldPrice: software.soldPrice?.toString() || "",
        soldDate: software.soldDate ? software.soldDate.split("T")[0] : "",
      });

      setAccessories(software.accessories?.map((a) => ({ id: a.id, name: a.name })) ?? []);
      setLinks(software.links?.map((l) => ({ id: l.id, label: l.label, url: l.url })) ?? []);

      if (software.customFieldValues) {
        const cfValues: Record<number, string> = {};
        for (const cfv of software.customFieldValues) cfValues[cfv.customFieldId] = cfv.value;
        setCustomFieldFormValues(cfValues);
      }
    }
  }, [software, mode]);

  const templates: Template[] = (templatesData?.templates ?? []).filter((tpl: Template) =>
    allCategories.find((c) => c.id === tpl.categoryId)?.showSoftwareFields
  );

  const normalizedQuery = templateQuery.trim().toLowerCase();
  const filteredTemplates = templates.filter((tpl) => {
    if (!normalizedQuery) return true;
    const haystack = [tpl.name, tpl.additionalName, tpl.manufacturer, tpl.modelNumber].filter(Boolean).join(" ").toLowerCase();
    return haystack.includes(normalizedQuery);
  }).slice(0, 50);

  const showTemplateResults = normalizedQuery.length > 0;

  const applyTemplate = (tpl: Template) => {
    setSelectedTemplateId(tpl.id);
    setFormData((prev) => ({
      ...prev,
      name: tpl.name ?? prev.name,
      additionalName: tpl.additionalName ?? prev.additionalName,
      manufacturer: tpl.manufacturer ?? prev.manufacturer,
      modelNumber: tpl.modelNumber ?? prev.modelNumber,
      categoryId: tpl.categoryId ?? prev.categoryId,
      releaseYear: tpl.releaseYear ?? prev.releaseYear,
      estimatedValue: tpl.estimatedValue != null ? String(tpl.estimatedValue) : prev.estimatedValue,
      rarity: tpl.rarity ?? prev.rarity,
      historicalNotes: tpl.historicalNotes ?? prev.historicalNotes,
    }));
    if (tpl.externalUrl) {
      setLinks((prev) => {
        const label = tpl.externalLinkLabel || "Reference";
        if (prev.some((l) => l.url === tpl.externalUrl)) return prev;
        return [...prev, { label, url: tpl.externalUrl! }];
      });
    }
    setErrors({});
  };

  const applyMacintoshRepoResult = async (result: MacintoshRepoSearchResult) => {
    setMrSelectedUrl(result.url);
    setMrApplying(true);
    try {
      const res = await fetch(`/software-lookup/details?url=${encodeURIComponent(result.url)}`, { headers: authHeaders() });
      if (!res.ok) throw new Error("lookup failed");
      const details: MacintoshRepoDetails = await res.json();

      setFormData((prev) => {
        const next = { ...prev };
        if (details.name) next.name = details.name;
        if (details.author) next.manufacturer = details.author;
        if (details.year) next.releaseYear = details.year;
        next.downloadUrl = result.url;
        return next;
      });
      setErrors({});

      // Try to match any of their (possibly multiple, comma-separated) category
      // names against our own software sub-categories. Their naming doesn't always
      // match ours exactly (e.g. "First Person Shooter (FPS)" vs our "FPS"), so this
      // checks containment in either direction, not just an exact match.
      const candidateNames = details.categories?.length ? details.categories : (details.category ? [details.category] : []);
      for (const name of candidateNames) {
        const needle = name.toLowerCase();
        const match = softwareCategories.find((c) => {
          const hay = c.name.toLowerCase();
          return hay === needle || hay.includes(needle) || needle.includes(hay);
        });
        if (match) {
          setFormData((prev) => ({ ...prev, categoryId: match.id }));
          break;
        }
      }

      setLinks((prev) => {
        if (prev.some((l) => l.url === result.url)) return prev;
        return [...prev, { label: "Macintosh Repository", url: result.url }];
      });
    } catch {
      // best-effort — leave whatever fields were already filled in
    } finally {
      setMrApplying(false);
      setTemplateQuery("");
      setMrResults([]);
    }
  };

  const showSalesFields = ["FOR_SALE", "PENDING_SALE", "SOLD", "DONATED"].includes(formData.status);
  const showSoldFields = formData.status === "SOLD";
  const showDonatedFields = formData.status === "DONATED";
  const showDateField = showSoldFields || showDonatedFields;
  const showRepairFeeField = formData.status === "RETURNED";

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>) => {
    const { name, value, type } = e.target;
    const checked = (e.target as HTMLInputElement).checked;

    const nextValue = (() => {
      if (type === "checkbox") return checked;
      if (name === "categoryId" || name === "releaseYear") {
        const n = parseInt(value, 10);
        return Number.isNaN(n) ? 0 : n;
      }
      return value;
    })();

    setFormData((prev) => {
      const updates: any = { [name]: nextValue };
      if (name === "status" && (value === "SOLD" || value === "DONATED" || value === "RETURNED") && !prev.soldDate) {
        updates.soldDate = getLocalDateInputValue();
      }
      return { ...prev, ...updates };
    });

    if (errors[name]) setErrors((prev) => ({ ...prev, [name]: "" }));
  };

  const validate = () => {
    const newErrors: Record<string, string> = {};
    if (!formData.name.trim()) newErrors.name = "Name is required";
    if (!formData.categoryId) newErrors.categoryId = "Category is required";
    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const parseLocalDate = (dateStr: string) => {
    const [year, month, day] = dateStr.split("-").map(Number);
    return new Date(year, month - 1, day, 12, 0, 0).toISOString();
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!validate()) return;

    const input: any = {
      name: formData.name,
      categoryId: parseInt(formData.categoryId.toString()),
      status: formData.status,
      functionalStatus: "UNKNOWN",
      isFavorite: formData.isFavorite,
      isAssetTagged: formData.isAssetTagged,
      requiresDongle: formData.requiresDongle,
      hasOriginalManuals: formData.hasOriginalManuals,
    };

    if (formData.additionalName) input.additionalName = formData.additionalName;
    if (formData.manufacturer) input.manufacturer = formData.manufacturer;
    if (formData.modelNumber) input.modelNumber = formData.modelNumber;
    if (formData.locationId) input.locationId = formData.locationId;
    if (formData.platform) input.platform = formData.platform;
    if (formData.licenceKey) input.licenceKey = formData.licenceKey;
    if (formData.downloadUrl) input.downloadUrl = formData.downloadUrl;
    if (formData.localPath) input.localPath = formData.localPath;
    if (formData.info) input.info = formData.info;
    if (formData.historicalNotes) input.historicalNotes = formData.historicalNotes;
    if (formData.externalUrl) input.externalUrl = formData.externalUrl;
    if (formData.whereAcquired) input.whereAcquired = formData.whereAcquired;
    if (formData.condition) input.condition = formData.condition;
    if (formData.rarity) input.rarity = formData.rarity;

    if (formData.releaseYear) input.releaseYear = parseInt(formData.releaseYear.toString());
    if (formData.priceAcquired) input.priceAcquired = parseFloat(formData.priceAcquired);
    if (formData.estimatedValue) input.estimatedValue = parseFloat(formData.estimatedValue);
    if (formData.listPrice) input.listPrice = parseFloat(formData.listPrice);
    if (formData.soldPrice) input.soldPrice = parseFloat(formData.soldPrice);

    if (formData.dateAcquired) input.dateAcquired = parseLocalDate(formData.dateAcquired);
    if (formData.soldDate) input.soldDate = parseLocalDate(formData.soldDate);

    try {
      let deviceId: number;
      if (mode === "create") {
        const result = await createDevice({ variables: { input } });
        deviceId = result.data.createDevice.id;
        apolloClient.cache.evict({ fieldName: "devices" });
        apolloClient.cache.gc();
      } else {
        await updateDevice({ variables: { input: { ...input, id: software!.id } } });
        deviceId = software!.id;
      }

      const customFields = customFieldsData?.customFields || [];
      const originalValues: Record<number, string> = {};
      if (software?.customFieldValues) {
        for (const cfv of software.customFieldValues) originalValues[cfv.customFieldId] = cfv.value;
      }
      for (const field of customFields) {
        const newValue = (customFieldFormValues[field.id] || "").trim();
        const oldValue = (originalValues[field.id] || "").trim();
        if (newValue && newValue !== oldValue) {
          await setCustomFieldValue({ variables: { input: { deviceId, customFieldId: field.id, value: newValue } } });
        } else if (!newValue && oldValue) {
          await removeCustomFieldValue({ variables: { deviceId, customFieldId: field.id } });
        }
      }

      if (mode === "create") {
        for (const acc of accessories) {
          await addDeviceAccessory({ variables: { deviceId, name: acc.name } });
        }
        for (const link of links) {
          await addDeviceLink({ variables: { deviceId, label: link.label, url: link.url } });
        }
      }

      router.push(`/devices/${deviceId}`);
    } catch (err) {
      console.error("Error saving software:", err);
    }
  };

  const loading = creating || updating;

  const handleAddAccessory = async (name: string) => {
    if (!name.trim() || accessories.some((a) => a.name === name.trim())) return;
    if (mode === "edit" && software?.id) {
      const res = await addDeviceAccessory({ variables: { deviceId: software.id, name: name.trim() } });
      setAccessories((prev) => [...prev, { id: res.data.addDeviceAccessory.id, name: name.trim() }]);
    } else {
      setAccessories((prev) => [...prev, { name: name.trim() }]);
    }
    setNewAccessoryName("");
  };

  const handleRemoveAccessory = async (index: number) => {
    const acc = accessories[index];
    if (mode === "edit" && acc.id) await removeDeviceAccessory({ variables: { id: acc.id } });
    setAccessories((prev) => prev.filter((_, i) => i !== index));
  };

  const handleAddLink = async () => {
    if (!newLinkLabel.trim() || !newLinkUrl.trim()) return;
    if (mode === "edit" && software?.id) {
      const res = await addDeviceLink({ variables: { deviceId: software.id, label: newLinkLabel.trim(), url: newLinkUrl.trim() } });
      setLinks((prev) => [...prev, { id: res.data.addDeviceLink.id, label: newLinkLabel.trim(), url: newLinkUrl.trim() }]);
    } else {
      setLinks((prev) => [...prev, { label: newLinkLabel.trim(), url: newLinkUrl.trim() }]);
    }
    setNewLinkLabel("");
    setNewLinkUrl("");
  };

  const handleRemoveLink = async (index: number) => {
    const link = links[index];
    if (mode === "edit" && link.id) await removeDeviceLink({ variables: { id: link.id } });
    setLinks((prev) => prev.filter((_, i) => i !== index));
  };

  const linkLabelSuggestions = ["Macintosh Garden", "Macintosh Repository", "68kMLA Thread", "Wikipedia", "Publisher Site"];

  return (
    <form onSubmit={handleSubmit} className="max-w-4xl">
      {mode === "create" && (
        <>
          <SectionHeader>Search Templates</SectionHeader>
          <div className="mb-8">
            <div className="max-w-2xl">
              <FormField label="Search">
                <div className="space-y-2">
                  <input
                    type="text"
                    value={templateQuery}
                    onChange={(e) => setTemplateQuery(e.target.value)}
                    className={inputClass}
                    placeholder="Search Macintosh Repository or your own templates..."
                  />
                  <p className="text-xs text-[var(--muted-foreground)]">
                    Live results come from Macintosh Repository, matched by the title's first letter (e.g. "Marathon" works, "Durandal" won't). Your own saved templates are also searched.
                  </p>

                  {mrApplying && (
                    <p className="text-xs text-[var(--apple-blue)]">Applying details…</p>
                  )}

                  {selectedTemplateId !== 0 && !mrSelectedUrl && (
                    <div className="flex items-center justify-between text-sm text-[var(--foreground)]">
                      <span>Selected: {templates.find((t) => t.id === selectedTemplateId)?.name}</span>
                      <button type="button" className="text-[var(--apple-blue)] hover:underline" onClick={() => { setSelectedTemplateId(0); setTemplateQuery(""); }}>
                        Clear
                      </button>
                    </div>
                  )}

                  {showTemplateResults && (
                    <div className="border border-[var(--border)] rounded max-h-72 overflow-auto bg-[var(--card)]">
                      {mrLoading && (
                        <div className="px-3 py-2 text-xs text-[var(--muted-foreground)]">Searching Macintosh Repository…</div>
                      )}
                      {mrResults.map((r) => (
                        <button
                          key={r.url}
                          type="button"
                          className="w-full text-left px-3 py-2 border-b border-[var(--border)] last:border-b-0 text-[var(--foreground)] bg-[var(--card)] hover:bg-[var(--muted)]"
                          onClick={() => applyMacintoshRepoResult(r)}
                        >
                          <div className="font-medium flex items-center gap-1.5">
                            {r.name}
                            <span className="text-[10px] font-medium px-1.5 py-0.5 rounded bg-blue-100 dark:bg-blue-900/30 text-blue-700 dark:text-blue-300">
                              Macintosh Repository
                            </span>
                          </div>
                          <div className="text-xs text-[var(--muted-foreground)]">{r.sectionLabel}{r.year ? ` - ${r.year}` : ""}</div>
                        </button>
                      ))}
                      {filteredTemplates.length === 0 && mrResults.length === 0 && !mrLoading ? (
                        <div className="px-3 py-2 text-sm text-[var(--muted-foreground)]">No matching results.</div>
                      ) : (
                        filteredTemplates.map((tpl) => (
                          <button
                            key={tpl.id}
                            type="button"
                            className={`w-full text-left px-3 py-2 border-b border-[var(--border)] last:border-b-0 text-[var(--foreground)] bg-[var(--card)] hover:bg-[var(--muted)] ${tpl.id === selectedTemplateId ? "bg-[var(--muted)]" : ""}`}
                            onClick={() => { applyTemplate(tpl); setTemplateQuery(""); }}
                          >
                            <div className="font-medium">{tpl.name}</div>
                            {tpl.manufacturer && <div className="text-xs text-[var(--muted-foreground)]">{tpl.manufacturer}{tpl.releaseYear ? ` - ${tpl.releaseYear}` : ""}</div>}
                          </button>
                        ))
                      )}
                    </div>
                  )}
                </div>
              </FormField>
            </div>
          </div>
        </>
      )}

      <SectionHeader>Basic Information</SectionHeader>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <FormField label="Category" required>
          <select name="categoryId" value={formData.categoryId} onChange={handleChange} className={`${selectClass} ${errors.categoryId ? "border-red-500" : ""}`}>
            <option value={0}>Select category...</option>
            {softwareCategories.map((cat) => (
              <option key={cat.id} value={cat.id}>
                {"\u00A0\u00A0".repeat(cat.depth)}{cat.depth > 0 ? "- " : ""}{cat.name}
              </option>
            ))}
          </select>
          {errors.categoryId && <p className="text-red-500 text-xs mt-1">{errors.categoryId}</p>}
          {softwareCategories.length === 0 && (
            <p className="text-xs text-[var(--muted-foreground)] mt-1">
              No software categories yet — tick &quot;Software-style form&quot; on a category in Manage Categories first.
            </p>
          )}
        </FormField>

        <FormField label="Name" required>
          <input type="text" name="name" value={formData.name} onChange={handleChange} className={`${inputClass} ${errors.name ? "border-red-500" : ""}`} placeholder="e.g. Marathon" />
          {errors.name && <p className="text-red-500 text-xs mt-1">{errors.name}</p>}
        </FormField>

        <FormField label="Additional Name">
          <input type="text" name="additionalName" value={formData.additionalName} onChange={handleChange} className={inputClass} placeholder="e.g. Durandal" />
        </FormField>

        <FormField label="Publisher">
          <input type="text" name="manufacturer" value={formData.manufacturer} onChange={handleChange} className={inputClass} placeholder="e.g. Bungie" />
        </FormField>

        <FormField label="Version">
          <input type="text" name="modelNumber" value={formData.modelNumber} onChange={handleChange} className={inputClass} placeholder="e.g. 1.2" />
        </FormField>

        <FormField label="Platform">
          <input type="text" name="platform" value={formData.platform} onChange={handleChange} className={inputClass} placeholder="e.g. Mac OS 7-9, Windows 95" />
        </FormField>

        <FormField label="Release Year">
          <input type="number" name="releaseYear" value={formData.releaseYear} onChange={handleChange} className={inputClass} min="1970" max={new Date().getFullYear()} />
        </FormField>

        <FormField label="Licence Key">
          <input type="text" name="licenceKey" value={formData.licenceKey} onChange={handleChange} className={inputClass} placeholder="Serial number / licence key" />
        </FormField>

        <FormField label="Location">
          <select value={formData.locationId ?? 0} onChange={(e) => setFormData((prev) => ({ ...prev, locationId: parseInt(e.target.value) || 0 }))} className={selectClass}>
            <option value={0}>None</option>
            {(locationsData?.locations ?? []).map((loc: { id: number; name: string }) => (
              <option key={loc.id} value={loc.id}>{loc.name}</option>
            ))}
          </select>
          <button
            type="button"
            className="mt-1 text-xs text-[var(--apple-blue)] hover:underline"
            onClick={async () => {
              const name = prompt("Location:");
              if (!name?.trim()) return;
              const result = await createLocationInline({ variables: { name: name.trim() } });
              await refetchLocations();
              const newId = result.data?.createLocation?.id;
              if (newId) setFormData((prev) => ({ ...prev, locationId: newId }));
            }}
          >
            + Create new location
          </button>
        </FormField>

        <FormField label="Download URL">
          <input type="url" name="downloadUrl" value={formData.downloadUrl} onChange={handleChange} className={inputClass} placeholder="https://..." />
        </FormField>

        <FormField label="Local Path">
          <input type="text" name="localPath" value={formData.localPath} onChange={handleChange} className={inputClass} placeholder="/Volumes/Archive/Software/..." />
        </FormField>
      </div>

      <SectionHeader>Status and Condition</SectionHeader>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <FormField label="Status">
          <select name="status" value={formData.status} onChange={handleChange} className={selectClass}>
            <option value="COLLECTION">{t.status.COLLECTION}</option>
            <option value="FOR_SALE">{t.status.FOR_SALE}</option>
            <option value="PENDING_SALE">{t.status.PENDING_SALE}</option>
            <option value="LOANED">{t.status.LOANED}</option>
            <option value="SOLD">{t.status.SOLD}</option>
            <option value="DONATED">{t.status.DONATED}</option>
            <option value="RETURNED">{t.status.RETURNED}</option>
          </select>
        </FormField>

        <FormField label="Condition">
          <select name="condition" value={formData.condition} onChange={handleChange} className={selectClass}>
            <option value="">{t.form.notSet}</option>
            <option value="NEW">{t.condition.NEW}</option>
            <option value="LIKE_NEW">{t.condition.LIKE_NEW}</option>
            <option value="VERY_GOOD">{t.condition.VERY_GOOD}</option>
            <option value="GOOD">{t.condition.GOOD}</option>
            <option value="ACCEPTABLE">{t.condition.ACCEPTABLE}</option>
            <option value="FOR_PARTS">{t.condition.FOR_PARTS}</option>
          </select>
        </FormField>

        <FormField label="Rarity">
          <select name="rarity" value={formData.rarity} onChange={handleChange} className={selectClass}>
            <option value="">{t.form.notSet}</option>
            <option value="COMMON">{t.rarity.COMMON}</option>
            <option value="UNCOMMON">{t.rarity.UNCOMMON}</option>
            <option value="RARE">{t.rarity.RARE}</option>
            <option value="VERY_RARE">{t.rarity.VERY_RARE}</option>
            <option value="EXTREMELY_RARE">{t.rarity.EXTREMELY_RARE}</option>
          </select>
        </FormField>

        <div className="md:col-span-2 flex flex-wrap gap-6">
          <label className="flex items-center gap-2 cursor-pointer">
            <input type="checkbox" name="isFavorite" checked={formData.isFavorite} onChange={handleChange} className="w-4 h-4 rounded border-[var(--border)] text-[var(--apple-blue)] focus:ring-[var(--apple-blue)]" />
            <span className="text-sm text-[var(--foreground)]">Favourite</span>
          </label>
          <label className="flex items-center gap-2 cursor-pointer">
            <input type="checkbox" name="isAssetTagged" checked={formData.isAssetTagged} onChange={handleChange} className="w-4 h-4 rounded border-[var(--border)] text-[var(--apple-blue)] focus:ring-[var(--apple-blue)]" />
            <span className="text-sm text-[var(--foreground)]">Asset Tagged</span>
          </label>
          <label className="flex items-center gap-2 cursor-pointer">
            <input type="checkbox" name="requiresDongle" checked={formData.requiresDongle} onChange={handleChange} className="w-4 h-4 rounded border-[var(--border)] text-[var(--apple-blue)] focus:ring-[var(--apple-blue)]" />
            <span className="text-sm text-[var(--foreground)]">Requires Dongle</span>
          </label>
          <label className="flex items-center gap-2 cursor-pointer">
            <input type="checkbox" name="hasOriginalManuals" checked={formData.hasOriginalManuals} onChange={handleChange} className="w-4 h-4 rounded border-[var(--border)] text-[var(--apple-blue)] focus:ring-[var(--apple-blue)]" />
            <span className="text-sm text-[var(--foreground)]">Has Original Manuals</span>
          </label>
        </div>
      </div>

      <SectionHeader>Acquisition</SectionHeader>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <FormField label="Date Acquired">
          <input type="date" name="dateAcquired" value={formData.dateAcquired} onChange={handleChange} className={inputClass} />
        </FormField>
        <FormField label="Where Acquired">
          <input type="text" name="whereAcquired" value={formData.whereAcquired} onChange={handleChange} className={inputClass} />
        </FormField>
        <FormField label="Price Acquired">
          <input type="number" name="priceAcquired" value={formData.priceAcquired} onChange={handleChange} className={inputClass} step="0.01" min="0" placeholder="0.00" />
        </FormField>
        <FormField label="Estimated Value">
          <input type="number" name="estimatedValue" value={formData.estimatedValue} onChange={handleChange} className={inputClass} step="0.01" min="0" placeholder="0.00" />
        </FormField>
      </div>

      {showRepairFeeField && (
        <>
          <SectionHeader>Repair Information</SectionHeader>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <FormField label="Repair Fee">
              <input type="number" name="soldPrice" value={formData.soldPrice} onChange={handleChange} className={inputClass} step="0.01" min="0" placeholder="0.00" />
            </FormField>
            <FormField label="Returned Date">
              <input type="date" name="soldDate" value={formData.soldDate} onChange={handleChange} className={inputClass} />
            </FormField>
          </div>
        </>
      )}

      {showSalesFields && (
        <>
          <SectionHeader>{showDonatedFields ? "Donation Information" : "Sales Information"}</SectionHeader>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {!showDonatedFields && (
              <FormField label="List Price">
                <input type="number" name="listPrice" value={formData.listPrice} onChange={handleChange} className={inputClass} step="0.01" min="0" placeholder="0.00" />
              </FormField>
            )}
            {showSoldFields && (
              <FormField label="Sold Price">
                <input type="number" name="soldPrice" value={formData.soldPrice} onChange={handleChange} className={inputClass} step="0.01" min="0" placeholder="0.00" />
              </FormField>
            )}
            {showDateField && (
              <FormField label={showDonatedFields ? "Donated Date" : "Sold Date"}>
                <input type="date" name="soldDate" value={formData.soldDate} onChange={handleChange} className={inputClass} />
              </FormField>
            )}
          </div>
        </>
      )}

      {customFieldsData?.customFields?.length > 0 && (
        <>
          <SectionHeader>Custom Fields</SectionHeader>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {customFieldsData.customFields.map((field: any) => (
              <FormField key={field.id} label={field.name}>
                <input
                  type="text"
                  value={customFieldFormValues[field.id] || ""}
                  onChange={(e) => setCustomFieldFormValues((prev) => ({ ...prev, [field.id]: e.target.value }))}
                  className={inputClass}
                />
              </FormField>
            ))}
          </div>
        </>
      )}

      <SectionHeader>Accessories</SectionHeader>
      <div>
        <div className="flex flex-wrap gap-2 mb-3">
          {accessories.map((acc, i) => (
            <span key={i} className="inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-medium bg-[var(--card)] border border-[var(--border)] text-[var(--foreground)]">
              {acc.name}
              <button type="button" onClick={() => handleRemoveAccessory(i)} className="text-[var(--muted-foreground)] hover:text-[var(--apple-red)] ml-1">{"\u00D7"}</button>
            </span>
          ))}
        </div>
        <div className="flex flex-wrap gap-1 mb-3">
          {softwareAccessorySuggestions.filter((s) => !accessories.some((a) => a.name === s)).map((s) => (
            <button key={s} type="button" onClick={() => handleAddAccessory(s)} className="px-2 py-1 text-xs rounded border border-dashed border-[var(--border)] text-[var(--muted-foreground)] hover:border-[var(--apple-blue)] hover:text-[var(--apple-blue)] transition-colors">
              + {s}
            </button>
          ))}
        </div>
        <div className="flex gap-2">
          <input
            type="text"
            value={newAccessoryName}
            onChange={(e) => setNewAccessoryName(e.target.value)}
            onKeyDown={(e) => { if (e.key === "Enter") { e.preventDefault(); handleAddAccessory(newAccessoryName); } }}
            className={`${inputClass} flex-1`}
            placeholder="Custom accessory..."
          />
          <button type="button" onClick={() => handleAddAccessory(newAccessoryName)} className="px-3 py-2 text-sm bg-[var(--apple-blue)] text-white rounded border border-[#007acc] hover:brightness-110 whitespace-nowrap">
            {t.common.add}
          </button>
        </div>
      </div>

      <SectionHeader>Reference Links</SectionHeader>
      <div>
        {links.length > 0 && (
          <div className="space-y-2 mb-3">
            {links.map((link, i) => (
              <div key={i} className="flex items-center gap-2 p-2 rounded border border-[var(--border)] bg-[var(--card)]">
                <span className="text-xs font-medium text-[var(--foreground)] min-w-0 flex-shrink-0">{link.label}</span>
                <a href={link.url} target="_blank" rel="noopener noreferrer" className="text-xs text-[var(--apple-blue)] hover:underline truncate flex-1 min-w-0">{link.url}</a>
                <button type="button" onClick={() => handleRemoveLink(i)} className="text-[var(--muted-foreground)] hover:text-[var(--apple-red)] flex-shrink-0">{"\u00D7"}</button>
              </div>
            ))}
          </div>
        )}
        <div className="flex flex-wrap gap-2">
          <input type="text" value={newLinkLabel} onChange={(e) => setNewLinkLabel(e.target.value)} list="software-link-label-suggestions" className={`${inputClass} flex-1`} style={{ minWidth: "120px" }} placeholder="Label" />
          <datalist id="software-link-label-suggestions">
            {linkLabelSuggestions.map((s) => <option key={s} value={s} />)}
          </datalist>
          <input type="url" value={newLinkUrl} onChange={(e) => setNewLinkUrl(e.target.value)} className={`${inputClass} flex-1`} style={{ minWidth: "120px" }} placeholder="URL" />
          <button type="button" onClick={handleAddLink} className="px-3 py-2 text-sm bg-[var(--apple-blue)] text-white rounded border border-[#007acc] hover:brightness-110 whitespace-nowrap">
            {t.common.add}
          </button>
        </div>
      </div>

      <SectionHeader>Additional Information</SectionHeader>
      <div className="grid grid-cols-1 gap-4">
        <FormField label="Description / Notes">
          <textarea name="info" value={formData.info} onChange={handleChange} className={`${inputClass} min-h-[100px]`} placeholder="Add any additional information..." />
        </FormField>
        <FormField label="Historical Notes">
          <textarea name="historicalNotes" value={formData.historicalNotes} onChange={handleChange} className={`${inputClass} min-h-[100px]`} placeholder="Historical context and significance of this title..." />
        </FormField>
      </div>

      <div className="sticky bottom-0 z-10 flex gap-3 mt-8 pt-4 pb-4 border-t border-[var(--border)] bg-[var(--background)]">
        <button type="submit" disabled={loading} className="px-6 py-2 bg-[var(--apple-blue)] text-white rounded border border-[#007acc] text-sm font-medium hover:brightness-110 disabled:opacity-50 disabled:cursor-not-allowed transition-colors">
          {loading ? "Saving..." : mode === "create" ? "Create Software" : "Save Changes"}
        </button>
        <button type="button" onClick={() => router.back()} className="btn-retro px-6 py-2 text-sm font-medium">
          {t.common.cancel}
        </button>
      </div>
    </form>
  );
}
