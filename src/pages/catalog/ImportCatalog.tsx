import React, { useState, useRef, useEffect } from 'react';
import { X, Upload, FileSpreadsheet, FileText, AlertCircle, CheckCircle2, Loader2 } from 'lucide-react';
import * as XLSX from 'xlsx';
import Papa from 'papaparse';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useCreateCatalogItem } from '../../hooks/useCatalog';
import { useUIStore } from '../../stores/ui-store';
import { CatalogItem } from '../../types/catalog';

interface ImportCatalogProps {
  isOpen: boolean;
  onClose: () => void;
  onImportComplete: () => void;
}

interface ParsedRow {
  sku: string;
  name: string;
  description?: string;
  item_type?: string;
  measure_basis?: string;
  uom?: string;
  is_fabric?: boolean | string;
  roll_width_m?: number | string;
  fabric_pricing_mode?: string;
  unit_price: number | string;
  cost_price: number | string;
  active?: boolean | string;
  discontinued?: boolean | string;
  manufacturer?: string;
  category?: string;
  family?: string;
}

interface ValidationError {
  row: number;
  field: string;
  message: string;
}

interface ImportResult {
  success: number;
  failed: number;
  errors: ValidationError[];
}

export default function ImportCatalog({ isOpen, onClose, onImportComplete }: ImportCatalogProps) {
  const { activeOrganizationId } = useOrganizationContext();
  const { createItem } = useCreateCatalogItem();
  const fileInputRef = useRef<HTMLInputElement>(null);
  
  const [file, setFile] = useState<File | null>(null);
  const [parsedData, setParsedData] = useState<ParsedRow[]>([]);
  const [validationErrors, setValidationErrors] = useState<ValidationError[]>([]);
  const [isProcessing, setIsProcessing] = useState(false);
  const [importResult, setImportResult] = useState<ImportResult | null>(null);
  const [currentStep, setCurrentStep] = useState<'upload' | 'preview' | 'result'>('upload');

  // Reset state when modal closes
  useEffect(() => {
    if (!isOpen) {
      setFile(null);
      setParsedData([]);
      setValidationErrors([]);
      setImportResult(null);
      setCurrentStep('upload');
      setIsProcessing(false);
      // Reset file input
      if (fileInputRef.current) {
        fileInputRef.current.value = '';
      }
    }
  }, [isOpen]);

  if (!isOpen) return null;

  const handleFileSelect = async (event: React.ChangeEvent<HTMLInputElement>) => {
    const selectedFile = event.target.files?.[0];
    if (!selectedFile) return;

    setFile(selectedFile);
    setParsedData([]);
    setValidationErrors([]);
    setImportResult(null);
    setCurrentStep('upload');

    try {
      const data = await parseFile(selectedFile);
      setParsedData(data);
      
      // Validate data
      const errors = validateData(data);
      setValidationErrors(errors);
      
      if (errors.length === 0) {
        setCurrentStep('preview');
      } else {
        useUIStore.getState().addNotification({
          type: 'error',
          title: 'Validation Errors',
          message: `Found ${errors.length} validation errors. Please review and fix them.`,
        });
      }
    } catch (error) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error parsing file',
        message: error instanceof Error ? error.message : 'Unknown error occurred',
      });
    }
  };

  const parseFile = async (file: File): Promise<ParsedRow[]> => {
    return new Promise((resolve, reject) => {
      const fileExtension = file.name.split('.').pop()?.toLowerCase();

      if (fileExtension === 'csv') {
        Papa.parse(file, {
          header: true,
          skipEmptyLines: true,
          complete: (results: any) => {
            if (results.errors.length > 0) {
              reject(new Error(`CSV parsing errors: ${results.errors.map((e: any) => e.message).join(', ')}`));
              return;
            }
            resolve(results.data as ParsedRow[]);
          },
          error: (error: any) => {
            reject(new Error(`CSV parsing error: ${error.message}`));
          },
        });
      } else if (fileExtension === 'xlsx' || fileExtension === 'xls') {
        const reader = new FileReader();
        reader.onload = (e) => {
          try {
            const data = new Uint8Array(e.target?.result as ArrayBuffer);
            const workbook = XLSX.read(data, { type: 'array' });
          const firstSheetName = workbook.SheetNames[0];
          if (!firstSheetName) {
            reject(new Error('Workbook has no sheets'));
            return;
          }
          const worksheet = workbook.Sheets[firstSheetName];
          if (!worksheet) {
            reject(new Error('Worksheet not found'));
            return;
          }
          const jsonData = XLSX.utils.sheet_to_json(worksheet);
            resolve(jsonData as ParsedRow[]);
          } catch (error) {
            reject(new Error(`Excel parsing error: ${error instanceof Error ? error.message : 'Unknown error'}`));
          }
        };
        reader.onerror = () => {
          reject(new Error('Error reading Excel file'));
        };
        reader.readAsArrayBuffer(file);
      } else {
        reject(new Error('Unsupported file format. Please use CSV or Excel (.xlsx, .xls)'));
      }
    });
  };

  const validateData = (data: ParsedRow[]): ValidationError[] => {
    const errors: ValidationError[] = [];

    data.forEach((row, index) => {
      const rowNum = index + 2; // +2 because index is 0-based and we skip header

      // Required fields
      if (!row.sku || row.sku.toString().trim() === '') {
        errors.push({ row: rowNum, field: 'sku', message: 'SKU is required' });
      }

      if (!row.name || row.name.toString().trim() === '') {
        errors.push({ row: rowNum, field: 'name', message: 'Name is required' });
      }

      // Validate item_type
      if (row.item_type) {
        const validTypes = ['component', 'fabric', 'linear', 'service', 'accessory'];
        if (!validTypes.includes(row.item_type.toLowerCase())) {
          errors.push({ 
            row: rowNum, 
            field: 'item_type', 
            message: `Invalid item_type. Must be one of: ${validTypes.join(', ')}` 
          });
        }
      }

      // Validate measure_basis
      if (row.measure_basis) {
        const validBasis = ['unit', 'linear_m', 'area', 'fabric'];
        if (!validBasis.includes(row.measure_basis.toLowerCase())) {
          errors.push({ 
            row: rowNum, 
            field: 'measure_basis', 
            message: `Invalid measure_basis. Must be one of: ${validBasis.join(', ')}` 
          });
        }
      }

      // Validate numeric fields
      const unitPrice = parseFloat(row.unit_price?.toString() || '0');
      if (isNaN(unitPrice) || unitPrice < 0) {
        errors.push({ row: rowNum, field: 'unit_price', message: 'Unit price must be a valid number >= 0' });
      }

      const costPrice = parseFloat(row.cost_price?.toString() || '0');
      if (isNaN(costPrice) || costPrice < 0) {
        errors.push({ row: rowNum, field: 'cost_price', message: 'Cost price must be a valid number >= 0' });
      }

      // Validate is_fabric and related fields
      const isFabric = row.is_fabric === true || row.is_fabric === 'true' || row.is_fabric === 'TRUE' || row.is_fabric === '1';
      if (isFabric) {
        if (row.measure_basis && row.measure_basis.toLowerCase() !== 'fabric') {
          // If is_fabric is true, measure_basis should be 'fabric'
          errors.push({ 
            row: rowNum, 
            field: 'measure_basis', 
            message: 'If is_fabric is true, measure_basis should be "fabric"' 
          });
        }

        if (row.fabric_pricing_mode) {
          const validModes = ['per_linear_m', 'per_sqm'];
          if (!validModes.includes(row.fabric_pricing_mode.toLowerCase())) {
            errors.push({ 
              row: rowNum, 
              field: 'fabric_pricing_mode', 
              message: `Invalid fabric_pricing_mode. Must be one of: ${validModes.join(', ')}` 
            });
          }
        }

        if (row.fabric_pricing_mode === 'per_linear_m' || !row.fabric_pricing_mode) {
          const rollWidth = parseFloat(row.roll_width_m?.toString() || '0');
          if (isNaN(rollWidth) || rollWidth <= 0) {
            errors.push({ 
              row: rowNum, 
              field: 'roll_width_m', 
              message: 'Roll width is required for fabric items with per_linear_m pricing' 
            });
          }
        }
      }
    });

    return errors;
  };

  const handleImport = async () => {
    if (!activeOrganizationId || parsedData.length === 0) return;

    setIsProcessing(true);
    setImportResult(null);

    const result: ImportResult = {
      success: 0,
      failed: 0,
      errors: [],
    };

    // Process items in batches to avoid overwhelming the database
    const batchSize = 10;
    for (let i = 0; i < parsedData.length; i += batchSize) {
      const batch = parsedData.slice(i, i + batchSize);
      
      await Promise.all(
        batch.map(async (row, batchIndex) => {
          try {
            const itemData = transformRowToCatalogItem(row);
            await createItem(itemData);
            result.success++;
          } catch (error) {
            result.failed++;
            result.errors.push({
              row: i + batchIndex + 2, // +2 for header and 0-based index
              field: 'general',
              message: error instanceof Error ? error.message : 'Unknown error',
            });
          }
        })
      );
    }

    setImportResult(result);
    setCurrentStep('result');
    setIsProcessing(false);

    if (result.success > 0) {
      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Import Complete',
        message: `Successfully imported ${result.success} items${result.failed > 0 ? `, ${result.failed} failed` : ''}`,
      });
      onImportComplete();
    } else {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Import Failed',
        message: `Failed to import all items. ${result.errors.length} errors occurred.`,
      });
    }
  };

  const transformRowToCatalogItem = (row: ParsedRow): Omit<CatalogItem, 'id' | 'organization_id' | 'created_at' | 'updated_at' | 'deleted' | 'archived'> => {
    const isFabric = row.is_fabric === true || row.is_fabric === 'true' || row.is_fabric === 'TRUE' || row.is_fabric === '1';
    
    // Auto-determine measure_basis if not provided
    let measureBasis = row.measure_basis?.toLowerCase() || 'unit';
    if (isFabric && measureBasis !== 'fabric') {
      measureBasis = 'fabric';
    }

    // Map item_type to valid enum values
    const validItemTypes = ['component', 'fabric', 'linear', 'service', 'accessory'];
    let itemType = row.item_type?.toLowerCase() || 'component';
    if (!validItemTypes.includes(itemType)) {
      // Auto-determine item_type
      if (isFabric) {
        itemType = 'fabric';
      } else if (row.measure_basis?.toLowerCase() === 'linear_m') {
        itemType = 'linear';
      } else {
        itemType = 'component';
      }
    }

    // Build metadata
    const metadata: Record<string, any> = {};
    if (row.manufacturer) metadata.manufacturer = row.manufacturer;
    if (row.category) metadata.category = row.category;
    if (row.family) {
      metadata.family = row.family;
      // Parse compatible_product_types from family if it contains commas
      if (row.family.includes(',')) {
        const types = row.family.split(',').map(t => t.trim()).filter(t => t);
        if (types.length > 0) {
          metadata.compatible_product_types = types;
        }
      }
    }

    return {
      sku: row.sku.toString().trim(),
      name: row.name.toString().trim(),
      description: row.description?.toString().trim() || null,
      item_type: itemType as any, // Add item_type column
      measure_basis: measureBasis as any,
      uom: row.uom?.toString().trim() || 'unit',
      is_fabric: isFabric,
      roll_width_m: isFabric && row.roll_width_m ? parseFloat(row.roll_width_m.toString()) : null,
      fabric_pricing_mode: isFabric && row.fabric_pricing_mode ? (row.fabric_pricing_mode.toLowerCase() as any) : null,
      unit_price: parseFloat(row.unit_price.toString()) || 0,
      cost_price: parseFloat(row.cost_price.toString()) || 0,
      active: row.active === true || row.active === 'true' || row.active === 'TRUE' || row.active === '1' || row.active === undefined || row.active === '',
      discontinued: row.discontinued === true || row.discontinued === 'true' || row.discontinued === 'TRUE' || row.discontinued === '1' || false,
      metadata,
    };
  };

  const handleReset = () => {
    setFile(null);
    setParsedData([]);
    setValidationErrors([]);
    setImportResult(null);
    setCurrentStep('upload');
    if (fileInputRef.current) {
      fileInputRef.current.value = '';
    }
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
      <div className="relative bg-white rounded-lg shadow-xl max-w-4xl w-full max-h-[90vh] overflow-hidden flex flex-col">
        {/* Header */}
        <div className="flex items-center justify-between p-6 border-b border-gray-200">
          <div>
            <h2 className="text-xl font-semibold text-gray-900">Import Catalog Items</h2>
            <p className="text-sm text-gray-600 mt-1">Upload an Excel or CSV file to import catalog items</p>
          </div>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-gray-600 transition-colors"
            aria-label="Close"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Content */}
        <div className="flex-1 overflow-y-auto p-6">
          {currentStep === 'upload' && (
            <div className="space-y-4">
              <div className="border-2 border-dashed border-gray-300 rounded-lg p-8 text-center hover:border-primary transition-colors">
                <input
                  ref={fileInputRef}
                  type="file"
                  accept=".csv,.xlsx,.xls"
                  onChange={handleFileSelect}
                  className="hidden"
                  id="file-upload"
                />
                <label
                  htmlFor="file-upload"
                  className="cursor-pointer flex flex-col items-center"
                >
                  <div className="w-12 h-12 bg-gray-100 rounded-full flex items-center justify-center mb-4">
                    <Upload className="w-6 h-6 text-gray-600" />
                  </div>
                  <p className="text-sm font-medium text-gray-900 mb-1">
                    Click to upload or drag and drop
                  </p>
                  <p className="text-xs text-gray-500">
                    CSV or Excel files (.csv, .xlsx, .xls)
                  </p>
                </label>
              </div>

              {file && (
                <div className="bg-gray-50 rounded-lg p-4 flex items-center justify-between">
                  <div className="flex items-center gap-3">
                    {file.name.endsWith('.csv') ? (
                      <FileText className="w-5 h-5 text-gray-600" />
                    ) : (
                      <FileSpreadsheet className="w-5 h-5 text-gray-600" />
                    )}
                    <div>
                      <p className="text-sm font-medium text-gray-900">{file.name}</p>
                      <p className="text-xs text-gray-500">{(file.size / 1024).toFixed(2)} KB</p>
                    </div>
                  </div>
                  <button
                    onClick={handleReset}
                    className="text-xs text-gray-500 hover:text-gray-700"
                  >
                    Remove
                  </button>
                </div>
              )}

              {/* Expected columns info */}
              <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
                <p className="text-xs font-medium text-blue-900 mb-2">Expected Columns:</p>
                <div className="text-xs text-blue-800 space-y-1">
                  <p><strong>Required:</strong> sku, name, unit_price, cost_price</p>
                  <p><strong>Optional:</strong> description, item_type, measure_basis, uom, is_fabric, roll_width_m, fabric_pricing_mode, active, discontinued, manufacturer, category, family</p>
                </div>
              </div>
            </div>
          )}

          {currentStep === 'preview' && (
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <div>
                  <h3 className="text-lg font-medium text-gray-900">Preview Data</h3>
                  <p className="text-sm text-gray-600">{parsedData.length} items ready to import</p>
                </div>
                {validationErrors.length > 0 && (
                  <div className="flex items-center gap-2 text-sm text-red-600">
                    <AlertCircle className="w-4 h-4" />
                    <span>{validationErrors.length} validation errors</span>
                  </div>
                )}
              </div>

              {validationErrors.length > 0 && (
                <div className="bg-red-50 border border-red-200 rounded-lg p-4 max-h-48 overflow-y-auto">
                  <p className="text-xs font-medium text-red-900 mb-2">Validation Errors:</p>
                  <div className="space-y-1">
                    {validationErrors.slice(0, 20).map((error, index) => (
                      <p key={index} className="text-xs text-red-800">
                        Row {error.row}, {error.field}: {error.message}
                      </p>
                    ))}
                    {validationErrors.length > 20 && (
                      <p className="text-xs text-red-600 italic">... and {validationErrors.length - 20} more errors</p>
                    )}
                  </div>
                </div>
              )}

              <div className="border border-gray-200 rounded-lg overflow-hidden">
                <div className="overflow-x-auto max-h-96">
                  <table className="w-full text-xs">
                    <thead className="bg-gray-50 border-b border-gray-200">
                      <tr>
                        <th className="text-left py-2 px-3 font-medium text-gray-900">SKU</th>
                        <th className="text-left py-2 px-3 font-medium text-gray-900">Name</th>
                        <th className="text-left py-2 px-3 font-medium text-gray-900">Type</th>
                        <th className="text-left py-2 px-3 font-medium text-gray-900">Price</th>
                        <th className="text-left py-2 px-3 font-medium text-gray-900">Status</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-gray-200">
                      {parsedData.slice(0, 10).map((row, index) => (
                        <tr key={index} className="hover:bg-gray-50">
                          <td className="py-2 px-3 text-gray-700">{row.sku}</td>
                          <td className="py-2 px-3 text-gray-700">{row.name}</td>
                          <td className="py-2 px-3 text-gray-700">{row.item_type || 'N/A'}</td>
                          <td className="py-2 px-3 text-gray-700">${parseFloat(row.unit_price?.toString() || '0').toFixed(2)}</td>
                          <td className="py-2 px-3 text-gray-700">
                            {row.active === false || row.active === 'false' ? 'Inactive' : 'Active'}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
                {parsedData.length > 10 && (
                  <div className="bg-gray-50 px-3 py-2 text-xs text-gray-600 text-center border-t border-gray-200">
                    Showing first 10 of {parsedData.length} items
                  </div>
                )}
              </div>
            </div>
          )}

          {currentStep === 'result' && importResult && (
            <div className="space-y-4">
              <div className="text-center">
                {importResult.failed === 0 ? (
                  <CheckCircle2 className="w-16 h-16 text-green-600 mx-auto mb-4" />
                ) : (
                  <AlertCircle className="w-16 h-16 text-yellow-600 mx-auto mb-4" />
                )}
                <h3 className="text-lg font-medium text-gray-900 mb-2">Import Complete</h3>
                <div className="space-y-1 text-sm text-gray-600">
                  <p><strong className="text-green-600">{importResult.success}</strong> items imported successfully</p>
                  {importResult.failed > 0 && (
                    <p><strong className="text-red-600">{importResult.failed}</strong> items failed to import</p>
                  )}
                </div>
              </div>

              {importResult.errors.length > 0 && (
                <div className="bg-red-50 border border-red-200 rounded-lg p-4 max-h-48 overflow-y-auto">
                  <p className="text-xs font-medium text-red-900 mb-2">Errors:</p>
                  <div className="space-y-1">
                    {importResult.errors.slice(0, 20).map((error, index) => (
                      <p key={index} className="text-xs text-red-800">
                        Row {error.row}: {error.message}
                      </p>
                    ))}
                    {importResult.errors.length > 20 && (
                      <p className="text-xs text-red-600 italic">... and {importResult.errors.length - 20} more errors</p>
                    )}
                  </div>
                </div>
              )}
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="flex items-center justify-between p-6 border-t border-gray-200 bg-gray-50">
          <button
            onClick={onClose}
            className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors"
          >
            {currentStep === 'result' ? 'Close' : 'Cancel'}
          </button>
          <div className="flex items-center gap-3">
            {currentStep === 'preview' && (
              <>
                <button
                  onClick={handleReset}
                  className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors"
                >
                  Reset
                </button>
                <button
                  onClick={handleImport}
                  disabled={isProcessing || validationErrors.length > 0}
                  className="px-4 py-2 text-sm font-medium text-white bg-primary rounded-lg hover:bg-primary/90 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
                >
                  {isProcessing ? (
                    <>
                      <Loader2 className="w-4 h-4 animate-spin" />
                      Importing...
                    </>
                  ) : (
                    'Import Items'
                  )}
                </button>
              </>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

