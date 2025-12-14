// All countries in the Americas (North, Central, Caribbean, and South America)
export const COUNTRIES = [
  // North America
  "Canada",
  "United States",
  "Mexico",
  
  // Central America
  "Belize",
  "Costa Rica",
  "El Salvador",
  "Guatemala",
  "Honduras",
  "Nicaragua",
  "Panama",
  
  // Caribbean
  "Antigua and Barbuda",
  "Bahamas",
  "Barbados",
  "Cuba",
  "Dominica",
  "Dominican Republic",
  "Grenada",
  "Haiti",
  "Jamaica",
  "Saint Kitts and Nevis",
  "Saint Lucia",
  "Saint Vincent and the Grenadines",
  "Trinidad and Tobago",
  
  // South America
  "Argentina",
  "Bolivia",
  "Brazil",
  "Chile",
  "Colombia",
  "Ecuador",
  "Guyana",
  "Paraguay",
  "Peru",
  "Suriname",
  "Uruguay",
  "Venezuela",
  
  // Other (for any country not listed)
  "Other",
];

export const COUNTRY_OPTIONS = COUNTRIES.map(country => ({
  value: country,
  label: country,
}));

// For shadcn Select component
export const COUNTRY_SELECT_ITEMS = COUNTRIES;

