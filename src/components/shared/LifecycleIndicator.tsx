import { Check } from 'lucide-react';

export type Stage = 'quote' | 'proposal' | 'sales_order' | 'manufacturing';

export interface StageRef {
  label: string;
  ref?: string;
  href?: string;
  count?: number;
}

export interface LifecycleIndicatorProps {
  currentStage: Stage;
  stages: StageRef[];
}

const STAGE_ORDER: Stage[] = ['quote', 'proposal', 'sales_order', 'manufacturing'];

export default function LifecycleIndicator({ currentStage, stages }: LifecycleIndicatorProps) {
  const currentIdx = STAGE_ORDER.indexOf(currentStage);

  return (
    <div className="flex items-start gap-0 overflow-x-auto py-2">
      {stages.map((stage, idx) => {
        const stageKey = STAGE_ORDER[idx];
        const isCompleted = idx < currentIdx;
        const isCurrent = idx === currentIdx;
        const lineCompleted = idx < currentIdx;

        const content = (
          <div className="flex flex-col items-center shrink-0">
            <div
              className={`flex items-center justify-center rounded-full transition-colors ${
                isCompleted
                  ? 'bg-green-600 text-white'
                  : isCurrent
                    ? 'bg-blue-600 text-white scale-110'
                    : 'border-2 border-gray-300 bg-white text-gray-400'
              }`}
              style={{ width: 16, height: 16 }}
            >
              {isCompleted ? <Check className="w-2.5 h-2.5" strokeWidth={3} /> : null}
            </div>
            <span
              className={`mt-1 text-xs font-medium ${
                isCompleted ? 'text-green-600' : isCurrent ? 'text-blue-600' : 'text-gray-500'
              }`}
            >
              {stage.label}
            </span>
            {(stage.ref ?? stage.count != null) && (
              <span
                className={`text-xs ${
                  isCompleted ? 'text-green-600' : isCurrent ? 'text-blue-600' : 'text-gray-500'
                }`}
              >
                {stage.ref}
              </span>
            )}
          </div>
        );

        const stageEl = stage.href && (isCompleted || isCurrent) ? (
          <a
            href={stage.href}
            className="flex flex-col items-center shrink-0 hover:opacity-80 transition-opacity focus:outline-none focus:ring-2 focus:ring-primary/30 focus:ring-offset-1 rounded"
          >
            {content}
          </a>
        ) : (
          content
        );

        return (
          <div key={stageKey} className="flex items-center">
            {idx > 0 && (
              <div
                className={`shrink-0 mx-1 h-0.5 w-4 sm:w-6 ${
                  lineCompleted ? 'bg-green-600' : 'bg-gray-300'
                }`}
                aria-hidden
              />
            )}
            {stageEl}
          </div>
        );
      })}
    </div>
  );
}
