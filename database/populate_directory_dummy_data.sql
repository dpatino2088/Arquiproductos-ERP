-- ====================================================
-- Script SQL para poblar datos dummy del módulo Directory
-- Organization ID: 4de856e8-36ce-480a-952b-a2f5083c69d6
-- ====================================================

-- ====================================================
-- STEP 1: Insertar catálogos
-- ====================================================

-- ContactTitles
INSERT INTO "ContactTitles" (id, organization_id, title, description, created_at, updated_at, deleted, archived)
VALUES
    (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, 'Mr.', 'Mister', now(), now(), false, false),
    (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, 'Mrs.', 'Missus', now(), now(), false, false),
    (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, 'Ms.', 'Miss', now(), now(), false, false),
    (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, 'Dr.', 'Doctor', now(), now(), false, false),
    (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, 'Ing.', 'Ingeniero', now(), now(), false, false),
    (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, 'Arq.', 'Arquitecto', now(), now(), false, false),
    (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, 'Lic.', 'Licenciado', now(), now(), false, false),
    (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, 'Not Selected', 'Sin título', now(), now(), false, false);

-- CustomerTypes
INSERT INTO "CustomerTypes" (id, organization_id, name, description, created_at, updated_at, deleted, archived)
VALUES
    (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, 'Customer', 'Cliente regular', now(), now(), false, false),
    (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, 'Distributor', 'Distribuidor', now(), now(), false, false),
    (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, 'VIP', 'Cliente VIP', now(), now(), false, false),
    (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, 'Reseller', 'Revendedor', now(), now(), false, false),
    (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, 'Partner', 'Socio comercial', now(), now(), false, false);

-- VendorTypes
INSERT INTO "VendorTypes" (id, organization_id, name, description, created_at, updated_at, deleted, archived)
VALUES
    (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, 'Lighting', 'Proveedor de iluminación', now(), now(), false, false),
    (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, 'Automation', 'Proveedor de automatización', now(), now(), false, false),
    (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, 'Shades', 'Proveedor de cortinas y persianas', now(), now(), false, false),
    (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, 'Audio/Video', 'Proveedor de audio y video', now(), now(), false, false),
    (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, 'Security', 'Proveedor de seguridad', now(), now(), false, false),
    (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, 'HVAC', 'Proveedor de climatización', now(), now(), false, false);

-- ContractorRoles
INSERT INTO "ContractorRoles" (id, organization_id, role_name, description, created_at, updated_at, deleted, archived)
VALUES
    (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, 'Electrician', 'Electricista', now(), now(), false, false),
    (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, 'Plumber', 'Plomero', now(), now(), false, false),
    (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, 'Carpenter', 'Carpintero', now(), now(), false, false),
    (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, 'HVAC Technician', 'Técnico en climatización', now(), now(), false, false),
    (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, 'Installer', 'Instalador', now(), now(), false, false);

-- SiteTypes
INSERT INTO "SiteTypes" (id, organization_id, name, description, created_at, updated_at, deleted, archived)
VALUES
    (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, 'Residential', 'Residencial', now(), now(), false, false),
    (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, 'Commercial', 'Comercial', now(), now(), false, false),
    (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, 'Industrial', 'Industrial', now(), now(), false, false),
    (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, 'Office', 'Oficina', now(), now(), false, false);

-- ====================================================
-- STEP 2: Insertar DirectoryContacts (10 contactos)
-- ====================================================

DO $$
DECLARE
    title_mr_id uuid;
    title_mrs_id uuid;
    title_ms_id uuid;
    title_dr_id uuid;
    title_ing_id uuid;
    title_arq_id uuid;
    title_lic_id uuid;
    title_not_selected_id uuid;
    contact_ids uuid[];
BEGIN
    -- Obtener IDs de títulos
    SELECT id INTO title_mr_id FROM "ContactTitles" WHERE title = 'Mr.' AND organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid LIMIT 1;
    SELECT id INTO title_mrs_id FROM "ContactTitles" WHERE title = 'Mrs.' AND organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid LIMIT 1;
    SELECT id INTO title_ms_id FROM "ContactTitles" WHERE title = 'Ms.' AND organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid LIMIT 1;
    SELECT id INTO title_dr_id FROM "ContactTitles" WHERE title = 'Dr.' AND organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid LIMIT 1;
    SELECT id INTO title_ing_id FROM "ContactTitles" WHERE title = 'Ing.' AND organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid LIMIT 1;
    SELECT id INTO title_arq_id FROM "ContactTitles" WHERE title = 'Arq.' AND organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid LIMIT 1;
    SELECT id INTO title_lic_id FROM "ContactTitles" WHERE title = 'Lic.' AND organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid LIMIT 1;
    SELECT id INTO title_not_selected_id FROM "ContactTitles" WHERE title = 'Not Selected' AND organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid LIMIT 1;
    
    -- Insertar contactos con direcciones directamente en las columnas
    INSERT INTO "DirectoryContacts" (
        id, organization_id, contact_type, title_id, first_name, last_name, 
        primary_phone, cell_phone, alt_phone, email,
        street_address_line_1, street_address_line_2, city, state, zip_code, country,
        billing_street_address_line_1, billing_street_address_line_2, billing_city, billing_state, billing_zip_code, billing_country,
        created_at, updated_at, deleted, archived
    )
    VALUES
        (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, 'individual', title_ing_id, 'Carlos', 'Rodríguez', '+507 6678-9012', '+507 6123-4567', '+507 6789-0123', 'carlos.rodriguez@email.com', 'Calle 50, Edificio Torre Global', 'Piso 15, Oficina 1502', 'Panamá', 'Panamá', '0801', 'Panamá', 'Calle 50, Edificio Torre Global', 'Piso 15, Oficina 1502', 'Panamá', 'Panamá', '0801', 'Panamá', now(), now(), false, false),
        (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, 'individual', title_mrs_id, 'María', 'González', '+507 6678-9013', '+507 6123-4568', '+507 6789-0124', 'maria.gonzalez@email.com', 'Avenida Balboa, Torre del Mar', 'Piso 8', 'Panamá', 'Panamá', '0803', 'Panamá', 'Avenida Balboa, Torre del Mar', 'Piso 8', 'Panamá', 'Panamá', '0803', 'Panamá', now(), now(), false, false),
        (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, 'individual', title_arq_id, 'Roberto', 'Martínez', '+507 6678-9014', '+507 6123-4569', '+507 6789-0125', 'roberto.martinez@email.com', 'Calle 53 Este, San Francisco', 'Casa 12', 'Panamá', 'Panamá', '0804', 'Panamá', 'Calle 53 Este, San Francisco', 'Casa 12', 'Panamá', 'Panamá', '0804', 'Panamá', now(), now(), false, false),
        (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, 'individual', title_dr_id, 'Ana', 'López', '+507 6678-9015', '+507 6123-4570', '+507 6789-0126', 'ana.lopez@email.com', 'Avenida Samuel Lewis, Obarrio', 'Edificio Plaza 2000', 'Panamá', 'Panamá', '0805', 'Panamá', 'Avenida Samuel Lewis, Obarrio', 'Edificio Plaza 2000', 'Panamá', 'Panamá', '0805', 'Panamá', now(), now(), false, false),
        (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, 'individual', title_lic_id, 'Luis', 'Fernández', '+507 6678-9016', '+507 6123-4571', '+507 6789-0127', 'luis.fernandez@email.com', 'Calle 77, San Francisco', 'Casa 45', 'Panamá', 'Panamá', '0806', 'Panamá', 'Calle 77, San Francisco', 'Casa 45', 'Panamá', 'Panamá', '0806', 'Panamá', now(), now(), false, false),
        (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, 'individual', title_mr_id, 'Pedro', 'Sánchez', '+507 6678-9017', '+507 6123-4572', '+507 6789-0128', 'pedro.sanchez@email.com', 'Avenida Ricardo J. Alfaro, Costa del Este', 'Torre Empresarial', 'Panamá', 'Panamá', '0807', 'Panamá', 'Avenida Ricardo J. Alfaro, Costa del Este', 'Torre Empresarial', 'Panamá', 'Panamá', '0807', 'Panamá', now(), now(), false, false),
        (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, 'company', title_not_selected_id, NULL, NULL, '+507 6678-9018', NULL, '+507 6789-0129', 'info@empresatecnologia.com', 'Calle 50, El Cangrejo', 'Edificio Las Américas', 'Panamá', 'Panamá', '0808', 'Panamá', 'Calle 50, El Cangrejo', 'Edificio Las Américas', 'Panamá', 'Panamá', '0808', 'Panamá', now(), now(), false, false),
        (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, 'individual', title_ms_id, 'Laura', 'Torres', '+507 6678-9019', '+507 6123-4573', '+507 6789-0130', 'laura.torres@email.com', 'Avenida Federico Boyd, Bella Vista', 'Piso 10', 'Panamá', 'Panamá', '0809', 'Panamá', 'Avenida Federico Boyd, Bella Vista', 'Piso 10', 'Panamá', 'Panamá', '0809', 'Panamá', now(), now(), false, false),
        (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, 'individual', title_ing_id, 'Jorge', 'Ramírez', '+507 6678-9020', '+507 6123-4574', '+507 6789-0131', 'jorge.ramirez@email.com', 'Calle 72, San Francisco', 'Casa 23', 'Panamá', 'Panamá', '0810', 'Panamá', 'Calle 72, San Francisco', 'Casa 23', 'Panamá', 'Panamá', '0810', 'Panamá', now(), now(), false, false),
        (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, 'company', title_not_selected_id, NULL, NULL, '+507 6678-9021', NULL, '+507 6789-0132', 'contacto@construccionespanama.com', 'Avenida Manuel María Icaza, Punta Paitilla', 'Torre Oceanía', 'Panamá', 'Panamá', '0811', 'Panamá', 'Avenida Manuel María Icaza, Punta Paitilla', 'Torre Oceanía', 'Panamá', 'Panamá', '0811', 'Panamá', now(), now(), false, false)
    RETURNING id INTO contact_ids;
END $$;

-- ====================================================
-- STEP 3: Insertar DirectoryCustomers (8 customers)
-- ====================================================

DO $$
DECLARE
    customer_type_customer_id     uuid;
    customer_type_distributor_id  uuid;
    customer_type_vip_id          uuid;
    customer_type_reseller_id     uuid;
    customer_type_partner_id      uuid;
    contact_ids                   uuid[];
BEGIN
    -- Obtener tipos de cliente
    SELECT id INTO customer_type_customer_id
    FROM "CustomerTypes"
    WHERE name = 'Customer'
      AND organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid
    LIMIT 1;

    SELECT id INTO customer_type_distributor_id
    FROM "CustomerTypes"
    WHERE name = 'Distributor'
      AND organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid
    LIMIT 1;

    SELECT id INTO customer_type_vip_id
    FROM "CustomerTypes"
    WHERE name = 'VIP'
      AND organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid
    LIMIT 1;

    SELECT id INTO customer_type_reseller_id
    FROM "CustomerTypes"
    WHERE name = 'Reseller'
      AND organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid
    LIMIT 1;

    SELECT id INTO customer_type_partner_id
    FROM "CustomerTypes"
    WHERE name = 'Partner'
      AND organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid
    LIMIT 1;

    -- Tomar 10 contactos como candidatos a primary_contact_id
    SELECT ARRAY_AGG(id ORDER BY created_at) INTO contact_ids
    FROM "DirectoryContacts"
    WHERE organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid
    LIMIT 10;

    -- Insertar 8 clientes
    INSERT INTO "DirectoryCustomers" (
        id, organization_id, customer_type_id,
        company_name, ein,
        website, email, company_phone, alt_phone,
        street_address_line_1, street_address_line_2, city, state, zip_code, country,
        billing_street_address_line_1, billing_street_address_line_2,
        billing_city, billing_state, billing_zip_code, billing_country,
        primary_contact_id,
        created_at, updated_at, deleted, archived
    )
    VALUES
        (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, customer_type_vip_id, 'Empresa Tecnología S.A.', '123456789-1-2023', 'www.empresatecnologia.com', 'info@empresatecnologia.com', '+507 2234-5678', '+507 2234-5679', 'Calle 50, Marbella', 'Edificio Plaza Marbella', 'Panamá', 'Panamá', '0812', 'Panamá', 'Calle 50, Marbella', 'Edificio Plaza Marbella', 'Panamá', 'Panamá', '0812', 'Panamá', contact_ids[1], now(), now(), false, false),
        (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, customer_type_customer_id, 'Construcciones Panamá S.A.', '987654321-1-2023', 'www.construccionespanama.com', 'contacto@construccionespanama.com', '+507 2234-5680', '+507 2234-5681', 'Avenida 5 de Mayo, Calidonia', 'Edificio Comercial', 'Panamá', 'Panamá', '0813', 'Panamá', 'Avenida 5 de Mayo, Calidonia', 'Edificio Comercial', 'Panamá', 'Panamá', '0813', 'Panamá', contact_ids[2], now(), now(), false, false),
        (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, customer_type_distributor_id, 'Distribuidora Central S.A.', '456789123-1-2023', 'www.distribuidoracentral.com', 'ventas@distribuidoracentral.com', '+507 2234-5682', '+507 2234-5683', 'Calle 74, San Francisco', 'Casa 8', 'Panamá', 'Panamá', '0814', 'Panamá', 'Calle 74, San Francisco', 'Casa 8', 'Panamá', 'Panamá', '0814', 'Panamá', contact_ids[3], now(), now(), false, false),
        (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, customer_type_partner_id, 'Alianzas Comerciales S.A.', '789123456-1-2023', 'www.alianzascomerciales.com', 'socios@alianzascomerciales.com', '+507 2234-5684', '+507 2234-5685', 'Avenida España, Corregimiento de Calidonia', 'Torre España', 'Panamá', 'Panamá', '0815', 'Panamá', 'Avenida España, Corregimiento de Calidonia', 'Torre España', 'Panamá', 'Panamá', '0815', 'Panamá', contact_ids[4], now(), now(), false, false),
        (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, customer_type_customer_id, 'Inversiones del Istmo S.A.', '321654987-1-2023', 'www.inversionesistmo.com', 'info@inversionesistmo.com', '+507 2234-5686', '+507 2234-5687', 'Calle 51, Bella Vista', 'Edificio Los Pueblos', 'Panamá', 'Panamá', '0816', 'Panamá', 'Calle 51, Bella Vista', 'Edificio Los Pueblos', 'Panamá', 'Panamá', '0816', 'Panamá', contact_ids[5], now(), now(), false, false),
        (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, customer_type_reseller_id, 'Revendedores Unidos S.A.', '654987321-1-2023', 'www.revendedoresunidos.com', 'ventas@revendedoresunidos.com', '+507 2234-5688', '+507 2234-5689', 'Avenida Central, Casco Viejo', 'Casa Colonial', 'Panamá', 'Panamá', '0817', 'Panamá', 'Avenida Central, Casco Viejo', 'Casa Colonial', 'Panamá', 'Panamá', '0817', 'Panamá', contact_ids[6], now(), now(), false, false),
        (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, customer_type_vip_id, 'Grandes Clientes S.A.', '147258369-1-2023', 'www.grandesclientes.com', 'atencion@grandesclientes.com', '+507 2234-5690', '+507 2234-5691', 'Calle 50, Punta Paitilla', 'Torre Paitilla', 'Panamá', 'Panamá', '0818', 'Panamá', 'Calle 50, Punta Paitilla', 'Torre Paitilla', 'Panamá', 'Panamá', '0818', 'Panamá', contact_ids[7], now(), now(), false, false),
        (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, customer_type_customer_id, 'Servicios Profesionales S.A.', '369258147-1-2023', 'www.serviciosprofesionales.com', 'contacto@serviciosprofesionales.com', '+507 2234-5692', '+507 2234-5693', 'Avenida Ricardo J. Alfaro, Tocumen', 'Zona Industrial', 'Panamá', 'Panamá', '0819', 'Panamá', 'Avenida Ricardo J. Alfaro, Tocumen', 'Zona Industrial', 'Panamá', 'Panamá', '0819', 'Panamá', contact_ids[8], now(), now(), false, false);
END $$;

-- ====================================================
-- STEP 4: Insertar DirectoryVendors (8 vendors)
-- ====================================================

DO $$
DECLARE
    vendor_type_lighting_id uuid;
    vendor_type_automation_id uuid;
    vendor_type_shades_id uuid;
    vendor_type_audiovideo_id uuid;
    vendor_type_security_id uuid;
    vendor_type_hvac_id uuid;
BEGIN
    -- Obtener IDs de tipos de vendor
    SELECT id INTO vendor_type_lighting_id FROM "VendorTypes" WHERE name = 'Lighting' AND organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid LIMIT 1;
    SELECT id INTO vendor_type_automation_id FROM "VendorTypes" WHERE name = 'Automation' AND organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid LIMIT 1;
    SELECT id INTO vendor_type_shades_id FROM "VendorTypes" WHERE name = 'Shades' AND organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid LIMIT 1;
    SELECT id INTO vendor_type_audiovideo_id FROM "VendorTypes" WHERE name = 'Audio/Video' AND organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid LIMIT 1;
    SELECT id INTO vendor_type_security_id FROM "VendorTypes" WHERE name = 'Security' AND organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid LIMIT 1;
    SELECT id INTO vendor_type_hvac_id FROM "VendorTypes" WHERE name = 'HVAC' AND organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid LIMIT 1;
    
    -- Insertar vendors con direcciones directamente en las columnas
    INSERT INTO "DirectoryVendors" (
        id, organization_id, vendor_type_id, vendor_name, ein,
        website, email, work_phone, fax,
        street_address_line_1, street_address_line_2, city, state, zip_code, country,
        billing_street_address_line_1, billing_street_address_line_2, billing_city, billing_state, billing_zip_code, billing_country,
        created_at, updated_at, deleted, archived
    )
    VALUES
        (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, vendor_type_lighting_id, 'Iluminación Premium S.A.', '111222333-1-2023', 'www.iluminacionpremium.com', 'ventas@iluminacionpremium.com', '+507 2234-5700', '+507 2234-5701', 'Calle 50, El Cangrejo', 'Edificio Torre 50', 'Panamá', 'Panamá', '0820', 'Panamá', 'Calle 50, El Cangrejo', 'Edificio Torre 50', 'Panamá', 'Panamá', '0820', 'Panamá', now(), now(), false, false),
        (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, vendor_type_automation_id, 'Automatización Inteligente S.A.', '222333444-1-2023', 'www.automatizacioninteligente.com', 'info@automatizacioninteligente.com', '+507 2234-5702', '+507 2234-5703', 'Avenida Balboa, Cinta Costera', 'Torre Balboa', 'Panamá', 'Panamá', '0821', 'Panamá', 'Avenida Balboa, Cinta Costera', 'Torre Balboa', 'Panamá', 'Panamá', '0821', 'Panamá', now(), now(), false, false),
        (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, vendor_type_shades_id, 'Cortinas y Persianas S.A.', '333444555-1-2023', 'www.cortinasypersianas.com', 'contacto@cortinasypersianas.com', '+507 2234-5704', '+507 2234-5705', 'Calle 50, Edificio Torre Global', 'Piso 15, Oficina 1502', 'Panamá', 'Panamá', '0801', 'Panamá', 'Calle 50, Edificio Torre Global', 'Piso 15, Oficina 1502', 'Panamá', 'Panamá', '0801', 'Panamá', now(), now(), false, false),
        (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, vendor_type_audiovideo_id, 'Audio Video Pro S.A.', '444555666-1-2023', 'www.audiovideopro.com', 'ventas@audiovideopro.com', '+507 2234-5706', '+507 2234-5707', 'Avenida Balboa, Torre del Mar', 'Piso 8', 'Panamá', 'Panamá', '0803', 'Panamá', 'Avenida Balboa, Torre del Mar', 'Piso 8', 'Panamá', 'Panamá', '0803', 'Panamá', now(), now(), false, false),
        (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, vendor_type_security_id, 'Seguridad Total S.A.', '555666777-1-2023', 'www.seguridadtotal.com', 'info@seguridadtotal.com', '+507 2234-5708', '+507 2234-5709', 'Calle 53 Este, San Francisco', 'Casa 12', 'Panamá', 'Panamá', '0804', 'Panamá', 'Calle 53 Este, San Francisco', 'Casa 12', 'Panamá', 'Panamá', '0804', 'Panamá', now(), now(), false, false),
        (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, vendor_type_hvac_id, 'Climatización Profesional S.A.', '666777888-1-2023', 'www.climatizacionprofesional.com', 'contacto@climatizacionprofesional.com', '+507 2234-5710', '+507 2234-5711', 'Avenida Samuel Lewis, Obarrio', 'Edificio Plaza 2000', 'Panamá', 'Panamá', '0805', 'Panamá', 'Avenida Samuel Lewis, Obarrio', 'Edificio Plaza 2000', 'Panamá', 'Panamá', '0805', 'Panamá', now(), now(), false, false),
        (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, vendor_type_lighting_id, 'LED Solutions S.A.', '777888999-1-2023', 'www.ledsolutions.com', 'ventas@ledsolutions.com', '+507 2234-5712', '+507 2234-5713', 'Calle 77, San Francisco', 'Casa 45', 'Panamá', 'Panamá', '0806', 'Panamá', 'Calle 77, San Francisco', 'Casa 45', 'Panamá', 'Panamá', '0806', 'Panamá', now(), now(), false, false),
        (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, vendor_type_automation_id, 'Smart Home Systems S.A.', '888999000-1-2023', 'www.smarthomesystems.com', 'info@smarthomesystems.com', '+507 2234-5714', '+507 2234-5715', 'Avenida Ricardo J. Alfaro, Costa del Este', 'Torre Empresarial', 'Panamá', 'Panamá', '0807', 'Panamá', 'Avenida Ricardo J. Alfaro, Costa del Este', 'Torre Empresarial', 'Panamá', 'Panamá', '0807', 'Panamá', now(), now(), false, false)
    RETURNING id;
END $$;

-- ====================================================
-- STEP 5: Insertar DirectoryContractors (8 contractors)
-- ====================================================

DO $$
DECLARE
    contractor_role_electrician_id uuid;
    contractor_role_plumber_id uuid;
    contractor_role_carpenter_id uuid;
    contractor_role_hvac_id uuid;
    contractor_role_installer_id uuid;
BEGIN
    -- Obtener IDs de roles de contractor
    SELECT id INTO contractor_role_electrician_id FROM "ContractorRoles" WHERE role_name = 'Electrician' AND organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid LIMIT 1;
    SELECT id INTO contractor_role_plumber_id FROM "ContractorRoles" WHERE role_name = 'Plumber' AND organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid LIMIT 1;
    SELECT id INTO contractor_role_carpenter_id FROM "ContractorRoles" WHERE role_name = 'Carpenter' AND organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid LIMIT 1;
    SELECT id INTO contractor_role_hvac_id FROM "ContractorRoles" WHERE role_name = 'HVAC Technician' AND organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid LIMIT 1;
    SELECT id INTO contractor_role_installer_id FROM "ContractorRoles" WHERE role_name = 'Installer' AND organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid LIMIT 1;
    
    -- Insertar contractors con direcciones directamente en las columnas
    INSERT INTO "DirectoryContractors" (
        id, organization_id, contractor_role_id, contractor_company_name, contact_name, position,
        street_address_line_1, street_address_line_2, city, state, zip_code, country,
        date_of_hire, date_of_birth, ein, company_number,
        primary_email, secondary_email, phone, extension, cell_phone, fax,
        created_at, updated_at, deleted, archived
    )
    VALUES
        (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, contractor_role_electrician_id, 'Electricistas Profesionales S.A.', 'Juan Pérez', 'Electricista Senior', 'Calle 50, El Cangrejo', 'Edificio Las Américas', 'Panamá', 'Panamá', '0808', 'Panamá', '2020-01-15', '1985-05-20', '999888777-1-2023', 'EMP-001', 'juan.perez@electricistas.com', 'juan.perez.alt@electricistas.com', '+507 2234-5800', '101', '+507 6123-5800', '+507 2234-5801', now(), now(), false, false),
        (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, contractor_role_plumber_id, 'Plomería Express S.A.', 'Miguel Herrera', 'Plomero Jefe', 'Avenida Federico Boyd, Bella Vista', 'Piso 10', 'Panamá', 'Panamá', '0809', 'Panamá', '2019-03-10', '1988-08-15', '888777666-1-2023', 'EMP-002', 'miguel.herrera@plomeriaexpress.com', NULL, '+507 2234-5802', '102', '+507 6123-5801', '+507 2234-5803', now(), now(), false, false),
        (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, contractor_role_carpenter_id, 'Carpintería Artesanal S.A.', 'Carlos Mendoza', 'Maestro Carpintero', 'Calle 72, San Francisco', 'Casa 23', 'Panamá', 'Panamá', '0810', 'Panamá', '2018-06-20', '1982-11-30', '777666555-1-2023', 'EMP-003', 'carlos.mendoza@carpinteriaartesanal.com', 'carlos.mendoza.backup@carpinteriaartesanal.com', '+507 2234-5804', '103', '+507 6123-5802', NULL, now(), now(), false, false),
        (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, contractor_role_hvac_id, 'Climatización Técnica S.A.', 'Roberto Silva', 'Técnico HVAC', 'Avenida Manuel María Icaza, Punta Paitilla', 'Torre Oceanía', 'Panamá', 'Panamá', '0811', 'Panamá', '2021-02-14', '1990-04-25', '666555444-1-2023', 'EMP-004', 'roberto.silva@climatizaciontecnica.com', NULL, '+507 2234-5806', '104', '+507 6123-5803', '+507 2234-5807', now(), now(), false, false),
        (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, contractor_role_installer_id, 'Instalaciones Rápidas S.A.', 'Luis Morales', 'Instalador Certificado', 'Calle 50, Marbella', 'Edificio Plaza Marbella', 'Panamá', 'Panamá', '0812', 'Panamá', '2022-05-01', '1992-07-10', '555444333-1-2023', 'EMP-005', 'luis.morales@instalacionesrapidas.com', 'luis.morales.alt@instalacionesrapidas.com', '+507 2234-5808', '105', '+507 6123-5804', NULL, now(), now(), false, false),
        (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, contractor_role_electrician_id, 'Servicios Eléctricos S.A.', 'Fernando Castro', 'Electricista', 'Avenida 5 de Mayo, Calidonia', 'Edificio Comercial', 'Panamá', 'Panamá', '0813', 'Panamá', '2020-09-12', '1987-12-05', '444333222-1-2023', 'EMP-006', 'fernando.castro@servicioselectricos.com', NULL, '+507 2234-5810', '106', '+507 6123-5805', '+507 2234-5811', now(), now(), false, false),
        (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, contractor_role_plumber_id, 'Agua y Drenaje S.A.', 'Andrés Vega', 'Plomero', 'Calle 74, San Francisco', 'Casa 8', 'Panamá', 'Panamá', '0814', 'Panamá', '2019-11-08', '1989-03-18', '333222111-1-2023', 'EMP-007', 'andres.vega@aguaydrenaje.com', 'andres.vega.backup@aguaydrenaje.com', '+507 2234-5812', '107', '+507 6123-5806', NULL, now(), now(), false, false),
        (gen_random_uuid(), '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid, contractor_role_installer_id, 'Instalaciones Premium S.A.', 'Diego Ríos', 'Instalador Senior', 'Avenida España, Corregimiento de Calidonia', 'Torre España', 'Panamá', 'Panamá', '0815', 'Panamá', '2021-07-22', '1991-09-28', '222111000-1-2023', 'EMP-008', 'diego.rios@instalacionespremium.com', NULL, '+507 2234-5814', '108', '+507 6123-5807', '+507 2234-5815', now(), now(), false, false)
    RETURNING id;
END $$;

-- ====================================================
-- Verificación: Contar registros insertados
-- ====================================================

SELECT 'ContactTitles' as tabla, COUNT(*) as total FROM "ContactTitles" WHERE organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid
UNION ALL
SELECT 'CustomerTypes', COUNT(*) FROM "CustomerTypes" WHERE organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid
UNION ALL
SELECT 'VendorTypes', COUNT(*) FROM "VendorTypes" WHERE organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid
UNION ALL
SELECT 'ContractorRoles', COUNT(*) FROM "ContractorRoles" WHERE organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid
UNION ALL
SELECT 'SiteTypes', COUNT(*) FROM "SiteTypes" WHERE organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid
UNION ALL
SELECT 'DirectoryContacts', COUNT(*) FROM "DirectoryContacts" WHERE organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid
UNION ALL
SELECT 'DirectoryCustomers', COUNT(*) FROM "DirectoryCustomers" WHERE organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid
UNION ALL
SELECT 'DirectoryVendors', COUNT(*) FROM "DirectoryVendors" WHERE organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid
UNION ALL
SELECT 'DirectoryContractors', COUNT(*) FROM "DirectoryContractors" WHERE organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid;
