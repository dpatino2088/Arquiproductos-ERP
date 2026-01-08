/**
 * Hook to analyze BOMTemplate components and derive which configurator steps/questions to show
 * 
 * This hook determines:
 * - Which steps are required (variants, hardware, operatingSystem, accessories)
 * - Which boolean questions are needed (cassette, side_channel)
 * - Which select questions are needed (hardware_color, drive_type)
 */

import { useMemo } from 'react';
import { useBOMComponents, BOMComponent } from './useBOM';
import { CANONICAL_COMPONENT_ROLES } from '../lib/bom/roles';

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

export interface BOMTemplateQuestions {
  // Required steps
  requiredSteps: {
    variants: boolean; // Fabric/collection selection
    hardware: boolean; // Hardware color, cassette, side channel
    operatingSystem: boolean; // Drive type selection
    accessories: boolean; // Accessories selection
  };
  
  // Boolean questions (yes/no toggles)
  booleanQuestions: {
    cassette: boolean; // Whether to show cassette toggle
    side_channel: boolean; // Whether to show side_channel toggle
  };
  
  // Select questions (dropdown selections)
  selectQuestions: {
    hardware_color: boolean; // Whether to show hardware color selector
    drive_type: boolean; // Whether to show drive type selector
  };
}

/**
 * Hook to derive configurator questions from BOMTemplate components
 * 
 * @param bomTemplateId - BOM Template ID to analyze
 * @returns Questions object indicating which steps/questions to show
 */
export function useBOMTemplateQuestions(bomTemplateId: string | null | undefined): BOMTemplateQuestions {
  const { components, loading } = useBOMComponents(bomTemplateId || null);

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
      };
    }

    // If still loading, return defaults
    if (loading) {
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
      };
    }

    // ✅ FIX: Analyze components - Show steps based on component roles, not just auto_select
    // In MVP mode, components have auto_select=false but we still need to show steps if roles exist
    const hasFabric = components.some(
      (comp) => comp.component_role === 'fabric'
    );
    
    const hasColorizableAutoSelect = components.some(
      (comp) =>
        comp.component_role &&
        COLORIZABLE_ROLES.includes(comp.component_role as any)
    );
    
    const hasDriveManual = components.some(
      (comp) => comp.component_role === 'drive_manual'
    );
    
    const hasDriveMotorized = components.some(
      (comp) => comp.component_role === 'drive_motorized'
    );
    
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
    const hasCassetteComponent = components.some(
      (comp) => comp.component_role === 'cassette'
    );
    
    // Check if any component has side_channel role
    const hasSideChannelComponent = components.some(
      (comp) => comp.component_role === 'side_channel'
    );
    
    // Check for accessories
    const hasAccessories = components.some(
      (comp) => comp.component_role === 'accessory'
    );

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
        // Show hardware_color selector if there are auto-select colorizable components
        hardware_color: hasColorizableAutoSelect,
        // Show drive_type selector if there are drive components
        drive_type: hasDriveManual || hasDriveMotorized,
      },
    };
  }, [bomTemplateId, components, loading]);
}


