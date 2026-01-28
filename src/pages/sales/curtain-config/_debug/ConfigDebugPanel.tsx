/**
 * Debug Panel for BOM Template-Driven Configurator
 * TEMPORARY - Only shown in development mode
 */

import { UnifiedProductConfig } from '../../product-config/config-contract';
import { BOMTemplateQuestions } from '../../../../hooks/useBOMTemplateQuestions';

interface ConfigDebugPanelProps {
  config: Partial<UnifiedProductConfig>;
  bomTemplateId: string | null | undefined;
  templatesLoading: boolean;
  templatesCount: number;
  questions: BOMTemplateQuestions | null;
  questionsLoading: boolean;
}

export default function ConfigDebugPanel({
  config,
  bomTemplateId,
  templatesLoading,
  templatesCount,
  questions,
  questionsLoading,
}: ConfigDebugPanelProps) {
  // Only show in development
  if (!import.meta.env.DEV) {
    return null;
  }

  return (
    <div className="mt-4 p-4 bg-gray-100 border border-gray-300 rounded-lg text-xs font-mono">
      <div className="font-bold mb-2 text-gray-800">🐛 DEBUG PANEL (DEV ONLY)</div>
      <div className="space-y-2 text-gray-700">
        <div>
          <strong>product_type_id:</strong> {config.product_type_id || '(null)'}
        </div>
        <div>
          <strong>bom_template_id:</strong> {bomTemplateId || '(null)'}
          {bomTemplateId && <span className="ml-2 text-green-600">✓</span>}
          {!bomTemplateId && <span className="ml-2 text-red-600">✗ MISSING</span>}
        </div>
        <div>
          <strong>templates:</strong> {templatesLoading ? 'loading...' : `${templatesCount} found`}
        </div>
        <div>
          <strong>questions:</strong> {questionsLoading ? 'loading...' : questions ? 'ready' : 'not loaded'}
        </div>
        {questions && (
          <>
            <div>
              <strong>requiredSteps:</strong>
              <pre className="mt-1 ml-4 bg-white p-2 rounded text-xs overflow-auto">
                {JSON.stringify(questions.requiredSteps, null, 2)}
              </pre>
            </div>
            <div>
              <strong>selectQuestions:</strong>
              <pre className="mt-1 ml-4 bg-white p-2 rounded text-xs overflow-auto">
                {JSON.stringify(questions.selectQuestions, null, 2)}
              </pre>
            </div>
            <div>
              <strong>booleanQuestions:</strong>
              <pre className="mt-1 ml-4 bg-white p-2 rounded text-xs overflow-auto">
                {JSON.stringify(questions.booleanQuestions, null, 2)}
              </pre>
            </div>
          </>
        )}
        <div>
          <strong>config JSON:</strong>
          <pre className="mt-1 ml-4 bg-white p-2 rounded text-xs overflow-auto max-h-40">
            {JSON.stringify(config, null, 2)}
          </pre>
        </div>
      </div>
    </div>
  );
}

