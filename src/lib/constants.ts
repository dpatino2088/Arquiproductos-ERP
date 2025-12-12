export const COUNTRIES = [
  "Panama",
  "United States",
  "Mexico",
  "Costa Rica",
  "Colombia",
  "Other",
];

export const COUNTRY_OPTIONS = COUNTRIES.map(country => ({
  value: country,
  label: country,
}));

// For shadcn Select component
export const COUNTRY_SELECT_ITEMS = COUNTRIES;

