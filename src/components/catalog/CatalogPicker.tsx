import { useState, useEffect } from 'react';
import { useCatalogPicker, CatalogPickerPayload } from '../../hooks/useCatalogPicker';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '../ui/SelectShadcn';
import Label from '../ui/Label';

interface CatalogPickerProps {
  onSelect?: (payload: CatalogPickerPayload | null) => void;
  className?: string;
  disabled?: boolean;
}

export default function CatalogPicker({
  onSelect,
  className = '',
  disabled = false,
}: CatalogPickerProps) {
  const {
    rows,
    loading: isLoading,
    error,
    productTypes,
    collectionsByProductType,
    variantsByProductTypeAndCollection,
    skusByAll,
  } = useCatalogPicker();

  const [productTypeId, setProductTypeId] = useState<string>('');
  const [collectionName, setCollectionName] = useState<string | null>(null);
  const [variantName, setVariantName] = useState<string | null>(null);
  const [catalogItemId, setCatalogItemId] = useState<string>('');

  // Reset downstream selections when parent changes
  useEffect(() => {
    setCollectionName(null);
    setVariantName(null);
    setCatalogItemId('');
    onSelect?.(null);
  }, [productTypeId, onSelect]);

  useEffect(() => {
    setVariantName(null);
    setCatalogItemId('');
    onSelect?.(null);
  }, [collectionName, onSelect]);

  useEffect(() => {
    setCatalogItemId('');
    onSelect?.(null);
  }, [variantName, onSelect]);

  // Get filtered options using memoized helpers
  const collectionOptions = collectionsByProductType(productTypeId);
  const variantOptions = variantsByProductTypeAndCollection(productTypeId, collectionName || '');
  const skuOptions = skusByAll(productTypeId, collectionName, variantName);

  // Handle SKU selection and emit payload
  const handleSkuChange = (selectedCatalogItemId: string) => {
    setCatalogItemId(selectedCatalogItemId);
    const selectedRow = rows.find((row) => row.catalog_item_id === selectedCatalogItemId);
    if (selectedRow && onSelect) {
      const payload: CatalogPickerPayload = {
        product_type_id: selectedRow.product_type_id,
        product_type_code: selectedRow.product_type_code,
        collection_id: null, // No longer used - kept for compatibility
        collection_name: selectedRow.collection_name,
        variant_name: selectedRow.variant_name, // Now text, not FK
        catalog_item_id: selectedRow.catalog_item_id,
        sku: selectedRow.sku,
        item_name: selectedRow.item_name,
        catalog_name: selectedRow.catalog_name,
        label: selectedRow.label,
        uom: selectedRow.uom,
        measure_basis: selectedRow.measure_basis,
        item_type: selectedRow.item_type,
        roll_width_m: selectedRow.roll_width_m,
        is_fabric: selectedRow.is_fabric,
      };
      onSelect(payload);
    }
  };

  if (error) {
    return (
      <div className={`text-sm text-red-600 ${className}`}>
        Error loading catalog: {error}
      </div>
    );
  }

  return (
    <div className={`space-y-4 ${className}`}>
      {/* Product Type Dropdown */}
      <div>
        <Label htmlFor="product-type">Product Type</Label>
        <Select
          value={productTypeId}
          onValueChange={setProductTypeId}
          disabled={disabled || isLoading}
        >
          <SelectTrigger id="product-type">
            <SelectValue placeholder={isLoading ? 'Loading...' : 'Select Product Type'} />
          </SelectTrigger>
          <SelectContent>
            {productTypes.map((type) => (
              <SelectItem key={type.id} value={type.id}>
                {type.code} - {type.name}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>

      {/* Collection Dropdown */}
      {productTypeId && (
        <div>
          <Label htmlFor="collection">Collection</Label>
          <Select
            value={collectionName || ''}
            onValueChange={(value) => setCollectionName(value || null)}
            disabled={disabled || isLoading}
          >
            <SelectTrigger id="collection">
              <SelectValue placeholder="Select Collection" />
            </SelectTrigger>
            <SelectContent>
              {collectionOptions.map((collection) => (
                <SelectItem key={collection.id} value={collection.id}>
                  {collection.name}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
      )}

      {/* Variant Dropdown - Only show for fabrics (when collection is selected) */}
      {collectionName && (
        <div>
          <Label htmlFor="variant">Variant (Color)</Label>
          <Select
            value={variantName || ''}
            onValueChange={(value) => setVariantName(value || null)}
            disabled={disabled || isLoading}
          >
            <SelectTrigger id="variant">
              <SelectValue placeholder="Select Variant" />
            </SelectTrigger>
            <SelectContent>
              {variantOptions.map((variant) => (
                <SelectItem key={variant.id} value={variant.id}>
                  {variant.name}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
      )}

      {/* SKU Dropdown - Show when variant is selected (for fabrics) or when product type is selected (for non-fabrics) */}
      {(variantName || (productTypeId && !collectionName)) && (
        <div>
          <Label htmlFor="sku">SKU</Label>
          <Select
            value={catalogItemId}
            onValueChange={handleSkuChange}
            disabled={disabled || isLoading}
          >
            <SelectTrigger id="sku">
              <SelectValue placeholder="Select SKU" />
            </SelectTrigger>
            <SelectContent>
              {skuOptions.map((sku) => (
                <SelectItem key={sku.value} value={sku.value}>
                  {sku.label}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
      )}
    </div>
  );
}

