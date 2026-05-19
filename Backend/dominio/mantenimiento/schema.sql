-- ============================================================================
-- MTTO — Control de Inventario de Taller (Kumi · esquema public · tablas mtto_*)
-- DDL DE REFERENCIA. La fuente operativa son las migraciones Rails y db/schema.rb
-- (db/migrate/20260519000001..7). Lógica de negocio en services Rails, no en
-- triggers/vistas. Cantidades en NUMERIC para soportar líquidos fraccionarios.
-- ============================================================================

-- 1. CATEGORÍAS
CREATE TABLE mtto_categories (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    code VARCHAR(20),
    parent_category_id BIGINT REFERENCES mtto_categories(id) ON DELETE SET NULL,
    is_active BOOLEAN DEFAULT true,
    business_unit_id BIGINT REFERENCES business_units(id),
    created_by_id BIGINT, updated_by_id BIGINT,
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    updated_at TIMESTAMP NOT NULL DEFAULT now(),
    UNIQUE (name, business_unit_id), UNIQUE (code, business_unit_id)
);

-- 2. PRESENTACIONES (catálogo seleccionable)
CREATE TABLE mtto_pack_sizes (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,           -- "Tambor 200 L", "Caja x12"
    clv VARCHAR(20),
    base_quantity NUMERIC(14,4) NOT NULL, -- unidades base por presentación
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    business_unit_id BIGINT REFERENCES business_units(id),
    created_by_id BIGINT, updated_by_id BIGINT,
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    updated_at TIMESTAMP NOT NULL DEFAULT now(),
    UNIQUE (clv, business_unit_id)
);

-- 3. PRODUCTOS
CREATE TABLE mtto_products (
    id BIGSERIAL PRIMARY KEY,
    category_id BIGINT NOT NULL REFERENCES mtto_categories(id) ON DELETE RESTRICT,
    name VARCHAR(150) NOT NULL,
    description TEXT,
    sku VARCHAR(50) NOT NULL,                          -- SKU formal
    clv VARCHAR(30) NOT NULL,                          -- clave corta de taller (≠ sku)
    unit_of_measure VARCHAR(20) NOT NULL DEFAULT 'pieza', -- UNIDAD BASE
    cost_price NUMERIC(14,4),                          -- solo referencia
    suggested_retail_price NUMERIC(14,4),
    min_stock_quantity NUMERIC(14,4) DEFAULT 10,
    max_stock_quantity NUMERIC(14,4) DEFAULT 500,
    reorder_quantity NUMERIC(14,4) DEFAULT 50,
    lead_time_days INT DEFAULT 7,
    is_active BOOLEAN DEFAULT true,
    business_unit_id BIGINT REFERENCES business_units(id),
    created_by_id BIGINT, updated_by_id BIGINT,
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    updated_at TIMESTAMP NOT NULL DEFAULT now(),
    UNIQUE (sku, business_unit_id), UNIQUE (clv, business_unit_id)
);

-- 4. PROVEEDOR ↔ PRODUCTO (reutiliza tabla suppliers existente)
CREATE TABLE mtto_supplier_products (
    id BIGSERIAL PRIMARY KEY,
    supplier_id BIGINT NOT NULL REFERENCES suppliers(id) ON DELETE CASCADE,
    product_id BIGINT NOT NULL REFERENCES mtto_products(id) ON DELETE CASCADE,
    supplier_sku VARCHAR(50),
    supplier_name VARCHAR(150),
    supplier_price NUMERIC(14,4) NOT NULL,             -- precio por presentación
    pack_size_id BIGINT REFERENCES mtto_pack_sizes(id) ON DELETE RESTRICT,
    supplier_lead_time_days INT,
    min_order_quantity NUMERIC(14,4) DEFAULT 1,
    is_available BOOLEAN DEFAULT true,
    last_order_date DATE,
    last_price_update TIMESTAMP DEFAULT now(),
    business_unit_id BIGINT REFERENCES business_units(id),
    created_by_id BIGINT, updated_by_id BIGINT,
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    updated_at TIMESTAMP NOT NULL DEFAULT now(),
    UNIQUE (supplier_id, product_id)
);

-- 5. RECEPCIÓN
CREATE TABLE mtto_product_receipts (
    id BIGSERIAL PRIMARY KEY,
    receipt_number VARCHAR(50) NOT NULL,               -- REC-2026-001
    supplier_id BIGINT NOT NULL REFERENCES suppliers(id) ON DELETE RESTRICT,
    receipt_date TIMESTAMP DEFAULT now(),
    invoice_number VARCHAR(50), invoice_date DATE,
    status VARCHAR(30) DEFAULT 'in_progress',          -- draft|in_progress|completed|cancelled
    subtotal NUMERIC(14,2) DEFAULT 0,
    tax_amount NUMERIC(14,2) DEFAULT 0,
    total_amount NUMERIC(14,2) DEFAULT 0,
    notes TEXT, warehouse_location VARCHAR(100),
    received_by_id BIGINT,
    business_unit_id BIGINT REFERENCES business_units(id),
    created_by_id BIGINT, updated_by_id BIGINT,
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    updated_at TIMESTAMP NOT NULL DEFAULT now(),
    UNIQUE (receipt_number, business_unit_id)
);

-- 6. LÍNEAS DE RECEPCIÓN
CREATE TABLE mtto_product_receipt_items (
    id BIGSERIAL PRIMARY KEY,
    product_receipt_id BIGINT NOT NULL REFERENCES mtto_product_receipts(id) ON DELETE CASCADE,
    product_id BIGINT NOT NULL REFERENCES mtto_products(id) ON DELETE RESTRICT,
    pack_size_id BIGINT REFERENCES mtto_pack_sizes(id) ON DELETE RESTRICT,
    quantity_received NUMERIC(14,4) NOT NULL,          -- en presentaciones
    unit_cost NUMERIC(14,4) NOT NULL,                  -- costo por presentación
    quantity_received_base NUMERIC(14,4),              -- calculado por el service
    unit_cost_base NUMERIC(14,6),                      -- costo por unidad base
    line_total NUMERIC(14,2) GENERATED ALWAYS AS (quantity_received * unit_cost) STORED,
    quantity_accepted NUMERIC(14,4) NOT NULL,
    quantity_rejected NUMERIC(14,4) DEFAULT 0,
    rejection_reason VARCHAR(200),
    batch_number VARCHAR(50), expiry_date DATE,
    notes TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    updated_at TIMESTAMP NOT NULL DEFAULT now()
);

-- 7. INVENTARIO (single source of truth)
CREATE TABLE mtto_inventories (
    id BIGSERIAL PRIMARY KEY,
    product_id BIGINT NOT NULL UNIQUE REFERENCES mtto_products(id) ON DELETE RESTRICT,
    quantity_on_hand NUMERIC(14,4) DEFAULT 0,    -- valuada a average_cost
    quantity_recovered NUMERIC(14,4) DEFAULT 0,  -- residuo reutilizable, $0 (costo hundido)
    quantity_reserved NUMERIC(14,4) DEFAULT 0,
    quantity_available NUMERIC(14,4) GENERATED ALWAYS AS
        (quantity_on_hand + quantity_recovered - quantity_reserved) STORED,
    average_cost NUMERIC(14,6) DEFAULT 0,        -- promedio móvil ponderado
    last_counted_at TIMESTAMP,
    last_movement_at TIMESTAMP DEFAULT now(),
    business_unit_id BIGINT REFERENCES business_units(id),
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    updated_at TIMESTAMP NOT NULL DEFAULT now()
);

-- 8. MOVIMIENTOS (append-only)
CREATE TABLE mtto_inventory_movements (
    id BIGSERIAL PRIMARY KEY,
    product_id BIGINT NOT NULL REFERENCES mtto_products(id) ON DELETE RESTRICT,
    movement_type VARCHAR(30) NOT NULL,  -- receipt|transfer|residue_return|adjustment|damage
    source_type VARCHAR(30), source_id BIGINT,
    quantity NUMERIC(14,4) NOT NULL,     -- con signo, unidad base
    unit_cost NUMERIC(14,6),             -- 0 en residue_return / bucket recuperado
    cost_layer VARCHAR(20) DEFAULT 'average', -- average | recovered
    movement_date TIMESTAMP DEFAULT now(),
    created_by_id BIGINT,
    notes TEXT, reference_number VARCHAR(50), batch_number VARCHAR(50),
    business_unit_id BIGINT REFERENCES business_units(id),
    created_at TIMESTAMP NOT NULL DEFAULT now()
);

-- 9. CATÁLOGO DE SERVICIOS DE TALLER
CREATE TABLE mtto_services (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(150) NOT NULL,          -- "Cambio de aceite"
    clv VARCHAR(30), code VARCHAR(20),
    description TEXT,
    standard_time_minutes INT NOT NULL DEFAULT 0, -- tiempo estándar (agencia)
    category VARCHAR(50),
    is_active BOOLEAN DEFAULT true,
    business_unit_id BIGINT REFERENCES business_units(id),
    created_by_id BIGINT, updated_by_id BIGINT,
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    updated_at TIMESTAMP NOT NULL DEFAULT now(),
    UNIQUE (clv, business_unit_id)
);

-- 10. ÓRDENES DE TRABAJO
CREATE TABLE mtto_work_orders (
    id BIGSERIAL PRIMARY KEY,
    work_order_number VARCHAR(50) NOT NULL,  -- OT-2026-001
    status VARCHAR(30) DEFAULT 'draft', -- draft|activated|in_progress|paused|completed|cancelled
    work_order_type VARCHAR(30) DEFAULT 'corrective',
    vehicle_id BIGINT REFERENCES vehicles(id) ON DELETE SET NULL,
    scheduled_maintenance_id BIGINT REFERENCES scheduled_maintenances(id) ON DELETE SET NULL,
    mechanic_id BIGINT REFERENCES employees(id) ON DELETE RESTRICT, -- un mecánico por OT
    description TEXT, reason VARCHAR(200), notes TEXT,
    estimated_total_minutes INT DEFAULT 0,   -- cache = Σ servicios
    actual_minutes INT,                       -- derivado de timestamps
    requested_at TIMESTAMP DEFAULT now(),
    activated_at TIMESTAMP, started_at TIMESTAMP, paused_at TIMESTAMP,
    completed_at TIMESTAMP, cancelled_at TIMESTAMP,
    requested_by_id BIGINT, activated_by_id BIGINT, -- admin que activa (fase 1)
    business_unit_id BIGINT REFERENCES business_units(id),
    created_by_id BIGINT, updated_by_id BIGINT,
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    updated_at TIMESTAMP NOT NULL DEFAULT now(),
    UNIQUE (work_order_number, business_unit_id)
);

-- 11. SERVICIOS DE LA OT (alcance)
CREATE TABLE mtto_work_order_services (
    id BIGSERIAL PRIMARY KEY,
    work_order_id BIGINT NOT NULL REFERENCES mtto_work_orders(id) ON DELETE CASCADE,
    service_id BIGINT NOT NULL REFERENCES mtto_services(id) ON DELETE RESTRICT,
    estimated_time_minutes INT NOT NULL DEFAULT 0, -- copiado del catálogo, ajustable
    completed BOOLEAN DEFAULT false,
    notes TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    updated_at TIMESTAMP NOT NULL DEFAULT now()
    -- FASE 2 (aditivo, NO crear ahora): is_suggested BOOLEAN,
    --   suggestion_status VARCHAR(20), suggested_by_id BIGINT, approved_by_id BIGINT
);

-- 12. SALIDAS / TRANSFERENCIAS
CREATE TABLE mtto_inventory_transfers (
    id BIGSERIAL PRIMARY KEY,
    transfer_number VARCHAR(50) NOT NULL,    -- OUT-2026-001
    status VARCHAR(30) DEFAULT 'draft', -- draft|pending_approval|approved|completed|cancelled
    transfer_type VARCHAR(30) DEFAULT 'departmental', -- departmental | work_order
    work_order_id BIGINT REFERENCES mtto_work_orders(id) ON DELETE SET NULL,
    target_department VARCHAR(100),
    request_date TIMESTAMP DEFAULT now(), approval_date TIMESTAMP, transfer_date TIMESTAMP,
    reason VARCHAR(200), notes TEXT,
    requested_by_id BIGINT, approved_by_id BIGINT, transferred_by_id BIGINT,
    business_unit_id BIGINT REFERENCES business_units(id),
    created_by_id BIGINT, updated_by_id BIGINT,
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    updated_at TIMESTAMP NOT NULL DEFAULT now(),
    UNIQUE (transfer_number, business_unit_id)
);

-- 13. LÍNEAS DE SALIDA
CREATE TABLE mtto_inventory_transfer_items (
    id BIGSERIAL PRIMARY KEY,
    inventory_transfer_id BIGINT NOT NULL REFERENCES mtto_inventory_transfers(id) ON DELETE CASCADE,
    product_id BIGINT NOT NULL REFERENCES mtto_products(id) ON DELETE RESTRICT,
    quantity_requested NUMERIC(14,4) NOT NULL,
    quantity_approved NUMERIC(14,4),
    quantity_transferred NUMERIC(14,4) DEFAULT 0,         -- total entregado (unidad base)
    quantity_consumed_recovered NUMERIC(14,4) DEFAULT 0,  -- porción del bucket $0
    quantity_consumed_average NUMERIC(14,4) DEFAULT 0,    -- porción a average_cost
    quantity_residue_returned NUMERIC(14,4) DEFAULT 0,    -- residuo reutilizable ($0)
    unit_cost_charged NUMERIC(14,6),                      -- average_cost aplicado
    line_cost NUMERIC(14,2),                              -- costo cargado a OT/depto
    batch_number VARCHAR(50), notes TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    updated_at TIMESTAMP NOT NULL DEFAULT now()
);
