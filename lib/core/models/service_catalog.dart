const serviceTypeIds = <String>[
  'pool_cleaning',
  'garden_service',
  'general_cleaning',
  'property_check',
  'key_holding',
  'handyman',
  'pest_control',
  'other',
];

const serviceChecklistByType = <String, List<String>>{
  'pool_cleaning': <String>[
    'pool_filter_cleaned',
    'pool_chemicals_added',
    'pool_surface_skimmed',
    'pool_vacuumed',
    'pool_water_level_checked',
  ],
  'garden_service': <String>[
    'garden_mowed',
    'garden_hedges_trimmed',
    'garden_weeds_removed',
    'garden_irrigation_checked',
  ],
  'general_cleaning': <String>[
    'cleaning_floors_done',
    'cleaning_kitchen_done',
    'cleaning_bathroom_done',
    'cleaning_trash_removed',
  ],
  'property_check': <String>[
    'property_visual_inspection',
    'property_water_leaks_checked',
    'property_electricity_checked',
    'property_security_checked',
  ],
  'key_holding': <String>[
    'key_entry_exit_logged',
    'key_doors_windows_secured',
    'key_alarm_checked',
  ],
  'handyman': <String>[
    'handyman_minor_repairs_done',
    'handyman_fixtures_checked',
    'handyman_tools_supplies_checked',
  ],
  'pest_control': <String>[
    'pest_traps_checked',
    'pest_treatment_applied',
    'pest_activity_logged',
  ],
  'other': <String>[
    'other_service_completed',
  ],
};
