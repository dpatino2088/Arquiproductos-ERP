import { ChevronRight } from 'lucide-react';
import { cn } from '../../lib/utils';

export type StepStatus = 'completed' | 'active' | 'pending';

export interface LifecycleStep {
  id: 'quote' | 'proposal' | 'sales_order' | 'manufacturing';
  label: string;
  sublabel: string;
  status: StepStatus;
  href?: string;
}

export interface LifecycleIndicatorProps {
  steps: LifecycleStep[];
  title?: string;
}

export default function LifecycleIndicator({ steps = [], title = 'Origin & Progress' }: LifecycleIndicatorProps) {
  return (
    <div className="w-full min-w-0">
      {title && (
        <h3 className="text-sm font-medium text-gray-500 mb-3">{title}</h3>
      )}
      {/* Steps constrained to half container */}
      <div className="flex items-center gap-0 max-w-[50%] min-w-0">
        {(steps ?? []).map((step, index) => {
          const isLast = index === steps.length - 1;
          const isReached = step.status === 'completed' || step.status === 'active';
          const isActive = step.status === 'active';

          return (
            <div key={step.id} className="flex items-center flex-1 min-w-0">
              {/* Rectangular box — active uses same colors as Priority "Normal" label: bg #E6F0FF, text #366AF3 */}
              <div
                className={cn(
                  'flex items-center gap-1.5 py-1.5 px-2 rounded border flex-1 min-w-0',
                  step.status === 'completed' && 'bg-gray-200 border-gray-300 text-gray-800',
                  step.status === 'pending' && 'bg-white border-gray-200 text-gray-500'
                )}
                style={
                  isActive
                    ? { backgroundColor: '#E6F0FF', borderColor: '#E6F0FF', color: '#366AF3' }
                    : undefined
                }
              >
                <div className="flex flex-col min-w-0 flex-1">
                  <span
                    className={cn('text-xs font-medium leading-tight truncate')}
                    style={isActive ? { color: '#366AF3' } : undefined}
                    title={step.label}
                  >
                    {step.label}
                  </span>
                  <span
                    className={cn(
                      'text-[10px] leading-tight truncate',
                      !isActive && (isReached ? 'text-gray-600' : 'text-gray-400')
                    )}
                    style={isActive ? { color: '#366AF3' } : undefined}
                    title={step.sublabel}
                  >
                    {step.href ? (
                      <a
                        href={step.href}
                        className={cn('hover:underline')}
                        style={isActive ? { color: '#366AF3' } : undefined}
                      >
                        {step.sublabel}
                      </a>
                    ) : (
                      step.sublabel
                    )}
                  </span>
                </div>
              </div>

              {/* Chevron to next step */}
              {!isLast && (
                <ChevronRight
                  className={cn(
                    'w-4 h-4 flex-shrink-0 mx-0.5',
                    !isReached && 'text-gray-300',
                    isReached && !isActive && 'text-gray-500'
                  )}
                  style={isActive ? { color: '#366AF3' } : undefined}
                  aria-hidden
                />
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}
