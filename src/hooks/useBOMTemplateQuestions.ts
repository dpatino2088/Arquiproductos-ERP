/**
 * Hook to analyze BOMTemplate components and derive which configurator steps/questions to show
 * 
 * This hook determines:
 * - Which steps are required (variants, hardware, operatingSystem, accessories)
 * - Which boolean questions are needed (cassette, side_channel)
 * - Which select questions are needed (hardware_color, drive_type)
 */

import { useEffect, useMemo, useState } from 'react';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';
import { useBOMComponents } from './useBOM';
import { normalizeRole } from '../lib/bom/roles';

// Roles that can have color variants (hardware color applicable)
const COLORIZABLE_ROLES = [
  'bracket',
  'end_cap',
  'cassette',
  'side_channel',
  'bottom_bar',
  'bottom_rail',
  'hardware',
] as const;

export type RoleRequirement = 'required' | 'optional' | 'none';

export interface BOMTemplateQuestions {
  // Required steps
  requiredSteps: {
    variants: boolean;
    hardware: boolean;
    operatingSystem: boolean;
    accessories: boolean;
  };
  
  // Boolean questions (yes/no toggles)
  booleanQuestions: {
    cassette: boolean;
    side_channel: boolean;
  };
  
  // Select questions (dropdown selections)
  selectQuestions: {
    hardware_color: boolean;
    drive_type: boolean;
  };

  /**
   * Per-role requirement derived from BOMComponents.is_required.
   * 'required' = at least one component with this role has is_required=true
   * 'optional' = role exists but all components with it have is_required=false
   * 'none'     = role doesn't exist in the template
   */
  componentRequirements: Record<string, RoleRequirement>;
}

/**
 * Hook to derive configurator questions from BOMTemplate components
 * 
 * @param bomTemplateId - BOM Template ID to analyze
 * @returns Questions object indicating which steps/questions to show
 */
export function useBOMTemplateQuestions(bomTemplateId: string | null | undefined): BOMTemplateQuestions {
  const { activeOrganizationId } = useOrganizationContext();
  const { components, loading } = useBOMComponents(bomTemplateId || null);
  const [slots, setSlots] = useState<{ item_role: string | null }[]>([]);
  const [slotsLoading, setSlotsLoading] = useState(false);

  useEffect(() => {
    if (!bomTemplateId || !activeOrganizationId) {
      setSlots([]);
      return;
    }

    let isMounted = true;

    const fetchSlots = async () => {
      try {
        setSlotsLoading(true);
        const { data, error } = await supabase
          .from('BOMTemplateSlots')
          .select('item_role')
          .eq('organization_id', activeOrganizationId)
          .eq('bom_template_id', bomTemplateId);

        if (error) throw error;
        if (isMounted) {
          setSlots((data as { item_role: string | null }[]) || []);
        }
      } catch (err) {
        if (import.meta.env.DEV) {
          const errorDetails = err instanceof Error
            ? { message: err.message, name: err.name }
            : typeof err === 'object' && err !== null
            ? { message: (err as any).message || String(err), code: (err as any).code }
            : { message: String(err) };
          console.error('[useBOMTemplateQuestions] Error loading slots', errorDetails);
        }
      } finally {
        if (isMounted) setSlotsLoading(false);
      }
    };

    fetchSlots();

    return () => {
      isMounted = false;
    };
  }, [bomTemplateId, activeOrganizationId]);

  return useMemo(() => {
    // Default: show all steps if no bomTemplateId (fallback for compatibility)
    if (!bomTemplateId) {
      return {
        requiredSteps: {
          variants: true,
          hardware: true,
          operatingSystem: true,
          accessories: true,
        },
        booleanQuestions: {
          cassette: true,
          side_channel: true,
        },
        selectQuestions: {
          hardware_color: true,
          drive_type: true,
        },
        componentRequirements: {},
      };
    }

    const isLoading = loading || slotsLoading;
    if (isLoading) {
      return {
        requiredSteps: {
          variants: true,
          hardware: false,
          operatingSystem: false,
          accessories: false,
        },
        booleanQuestions: {
          cassette: false,
          side_channel: false,
        },
        selectQuestions: {
          hardware_color: false,
          drive_type: false,
        },
        componentRequirements: {},
      };
    }

    // ✅ FIX: Analyze components - Show steps based on component roles, not just auto_select
    // In MVP mode, components have auto_select=false but we still need to show steps if roles exist
    const roleSet = new Set(
      [
        ...components.map((comp) => normalizeRole(comp.component_role) || comp.component_role || ''),
        ...slots.map((slot) => normalizeRole(slot.item_role) || slot.item_role || ''),
      ].filter(Boolean)
    );

    const hasRole = (role: string) => roleSet.has(role);
    const hasAnyRole = (roles: string[]) => roles.some((role) => roleSet.has(role));

    const hasFabric = hasRole('fabric');
    
    const hasColorizableAutoSelect = hasAnyRole([...COLORIZABLE_ROLES]);
    
    const hasDriveManual = hasRole('drive_manual') || hasRole('drive');
    
    const hasDriveMotorized = hasRole('drive_motorized') || hasRole('motor');
    
    // Check for block_condition that references cassette
    const hasCassetteBlockCondition = components.some(
      (comp) =>
        comp.block_condition &&
        typeof comp.block_condition === 'object' &&
        (comp.block_condition as any).cassette === true
    );
    
    // Check for block_condition that references side_channel
    const hasSideChannelBlockCondition = components.some(
      (comp) =>
        comp.block_condition &&
        typeof comp.block_condition === 'object' &&
        (comp.block_condition as any).side_channel === true
    );
    
    // Check if any component has cassette role
    const hasCassetteComponent = hasRole('cassette') || hasRole('headbox');
    
    // Check if any component has side_channel role
    const hasSideChannelComponent = hasRole('side_channel');
    
    // Check for accessories
    const hasAccessories = hasRole('accessory');

    // Derive per-role requirement from is_required flag
    const componentRequirements: Record<string, RoleRequirement> = {};
    for (const comp of components) {
      const role = normalizeRole(comp.component_role) || comp.component_role || '';
      if (!role) continue;
      if (comp.is_required) {
        componentRequirements[role] = 'required';
      } else if (!(role in componentRequirements)) {
        componentRequirements[role] = 'optional';
      }
    }
    for (const slot of slots) {
      const role = normalizeRole(slot.item_role) || slot.item_role || '';
      if (role && !(role in componentRequirements)) {
        componentRequirements[role] = 'optional';
      }
    }

    // Build questions object
    return {
      requiredSteps: {
        variants: hasFabric, // Show variants step if fabric component exists
        hardware: hasColorizableAutoSelect || hasCassetteComponent || hasSideChannelComponent,
        operatingSystem: hasDriveManual || hasDriveMotorized,
        accessories: hasAccessories,
      },
      booleanQuestions: {
        // Show cassette toggle if:
        // 1. There's a component with cassette role, OR
        // 2. There's a block_condition that references cassette
        cassette: hasCassetteComponent || hasCassetteBlockCondition,
        // Show side_channel toggle if:
        // 1. There's a component with side_channel role, OR
        // 2. There's a block_condition that references side_channel
        side_channel: hasSideChannelComponent || hasSideChannelBlockCondition,
      },
      selectQuestions: {
        hardware_color: hasColorizableAutoSelect,
        drive_type: hasDriveManual || hasDriveMotorized,
      },
      componentRequirements,
    };
  }, [bomTemplateId, components, loading, slots, slotsLoading]);
}


