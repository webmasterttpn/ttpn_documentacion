# Manual Backend — Construcción paso a paso

> **Audiencia**: dev que nunca ha tocado Rails/Ruby.
> **Resultado**: API completo del portal corriendo en
> `localhost:3000/api/v1/portal/*` con autenticación, modelos,
> storage y mailers.
> **Tiempo estimado**: 12-20 horas distribuidas en varios días.
> **Pre-requisito**: completados los manuales
> `00_setup_docker_y_entorno.md`, `manual_supabase.md`,
> `manual_letter_opener.md`.

---

## Estructura del manual

| Bloque | Pasos | Objetivo |
|---|---|---|
| A | 1-3 | Crear branch + entender la estructura del repo Rails |
| B | 4-9 | Migrations: 6 tablas nuevas |
| C | 10-15 | Modelos con `has_secure_password`, validaciones, asociaciones |
| D | 16-20 | Mailers + templates de email |
| E | 21-26 | JWT encoder/decoder + servicios de confirmación/reset |
| F | 27-32 | Controllers del portal (auth + invoices) |
| G | 33-37 | Controllers admin de Kumi (gestión de supplier_users e invoices) |
| H | 38-41 | Rate limiting + CORS + audit events |
| I | 42-45 | Specs RSpec + Swagger |
| J | 46-48 | Verificación end-to-end con curl |

---

## Bloque A — Setup en `ttpngas`

### Paso 1 — Crear branch para el portal

#### Por qué

Todo el trabajo del backend va en una branch dedicada
(`feature/portal-proveedores`). Nunca en `transform_to_api` ni
en `main`.

#### Comando(s)

```bash
cd ttpngas
git checkout transform_to_api
git pull
git checkout -b feature/portal-proveedores
```

#### Salida esperada

```text
Switched to a new branch 'feature/portal-proveedores'
```

#### Verificación

```bash
git branch --show-current
```

Debe mostrar `feature/portal-proveedores`.

### Paso 2 — Tour rápido de la estructura Rails

#### Por qué

Antes de generar archivos, sepas dónde van.

#### Estructura crítica

```text
ttpngas/
├── app/
│   ├── controllers/api/v1/      ← controllers del API
│   ├── models/                  ← modelos ActiveRecord
│   ├── services/                ← lógica de negocio
│   ├── mailers/                 ← clases de email
│   ├── views/                   ← templates HTML/text de los emails
│   └── middleware/              ← middleware Rack
├── config/
│   ├── routes.rb                ← entrypoint de rutas
│   ├── routes/                  ← rutas por dominio (drawables)
│   ├── initializers/            ← config que corre al boot
│   └── environments/            ← dev/test/prod
├── db/
│   ├── migrate/                 ← migrations (timestamps)
│   └── schema.rb                ← estado actual de la DB (autogenerado)
└── spec/                        ← tests RSpec
```

#### Aprende esto antes de seguir

- **Convención sobre configuración**: el nombre del archivo importa.
  `app/models/supplier_user.rb` define la clase `SupplierUser` que
  mapea a la tabla `supplier_users`. No improvises.
- **Plural en tablas, singular en modelos**: `suppliers` (tabla) ↔
  `Supplier` (modelo).
- **Generators** (`rails generate ...`) crean archivos con plantilla.
  Úsalos siempre que se pueda en lugar de escribir desde cero.

### Paso 3 — Configurar JWT secret en Rails credentials

#### Por qué

Los JWT que generemos para `supplier_user` se firman con
`Rails.application.secret_key_base`. Ya existe y se comparte para el
JWT actual de `User` también — no hay que hacer nada nuevo, **solo
verificar**.

#### Verificación

```bash
docker compose exec kumi_api bundle exec rails runner \
  "puts Rails.application.secret_key_base.length"
```

Debe imprimir un número >= 128 (típicamente 128).

#### Si falla (es 0 o nil)

Genera uno:

```bash
docker compose exec kumi_api bundle exec rails secret
```

Pega el resultado en `ttpngas/.env`:

```bash
SECRET_KEY_BASE=<el-secret-que-genero>
```

Reinicia: `docker compose restart kumi_api`.

---

## Bloque B — Migrations

### Paso 4 — Migration: `create_supplier_users`

#### Por qué

Es la tabla central — un proveedor puede tener varios usuarios. Espejo
del modelo `ClientUser` (que ya existe en Kumi) pero para suppliers.

#### Comando(s)

```bash
docker compose exec kumi_api bundle exec rails generate migration \
  CreateSupplierUsers
```

#### Salida esperada

```text
    invoke  active_record
    create  db/migrate/20260522000001_create_supplier_users.rb
```

(el timestamp cambiará según la fecha real)

#### Edita el archivo generado

Reemplaza el contenido con:

```ruby
# frozen_string_literal: true

class CreateSupplierUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :supplier_users do |t|
      t.references :supplier, null: false, foreign_key: true, index: true
      t.references :business_unit, null: false, foreign_key: true

      t.string :email, null: false
      t.string :nombre, null: false
      t.string :password_digest, null: false

      # Confirmación de cuenta
      t.datetime :confirmed_at
      t.string :unlock_token

      # Reset de password
      t.string :reset_password_token
      t.datetime :reset_password_sent_at

      # Anti-brute-force
      t.integer :failed_attempts, default: 0, null: false
      t.datetime :locked_at

      # JWT (revocación por jti)
      t.string :jti, null: false

      # Forzar cambio de password (primer login)
      t.boolean :force_password_change, default: true, null: false

      # Trazabilidad
      t.boolean :active, default: false, null: false
      t.datetime :last_sign_in_at
      t.inet :last_sign_in_ip
      t.integer :sign_in_count, default: 0, null: false

      t.timestamps
    end

    add_index :supplier_users, :email, unique: true
    add_index :supplier_users, :jti, unique: true
    add_index :supplier_users, :reset_password_token, unique: true
  end
end
```

#### Aplicar

```bash
docker compose exec kumi_api bundle exec rails db:migrate
```

#### Salida esperada

```text
== 20260522000001 CreateSupplierUsers: migrating =============
-- create_table(:supplier_users)
   -> 0.05s
== 20260522000001 CreateSupplierUsers: migrated (0.05s) ======
```

#### Verificación

```bash
docker compose exec kumi_api bundle exec rails runner \
  "puts ActiveRecord::Base.connection.columns('supplier_users').map(&:name).inspect"
```

Debe listar todas las columnas que pusiste.

#### Si falla

- **`Mysql2::Error` o `PG::Error`** → revisa el `.env` del backend,
  asegúrate que la DB esté corriendo.
- **`Migration version conflict`** → otro dev ya creó una migration
  con timestamp similar. Re-genera tu migration (`rails generate`
  asigna timestamp nuevo).

### Paso 5 — Migration: `create_supplier_user_tokens`

#### Por qué

Tokens efímeros de confirmación y reset, almacenados como **SHA256
digest** (no en claro). Patrón anti-replay.

#### Comando(s)

```bash
docker compose exec kumi_api bundle exec rails generate migration \
  CreateSupplierUserTokens
```

#### Contenido

```ruby
# frozen_string_literal: true

class CreateSupplierUserTokens < ActiveRecord::Migration[7.1]
  def change
    create_table :supplier_user_tokens do |t|
      t.references :supplier_user, null: false, foreign_key: true, index: true
      t.string :token_digest, null: false
      t.string :purpose, null: false # 'confirmation' | 'reset_password'
      t.datetime :expires_at, null: false
      t.datetime :used_at

      t.timestamps
    end

    add_index :supplier_user_tokens, :token_digest, unique: true
    add_index :supplier_user_tokens, [:purpose, :expires_at]
  end
end
```

#### Aplicar y verificar

```bash
docker compose exec kumi_api bundle exec rails db:migrate
```

### Paso 6 — Migration: `create_supplier_audit_events`

```ruby
# frozen_string_literal: true

class CreateSupplierAuditEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :supplier_audit_events do |t|
      t.references :supplier_user, foreign_key: true # nullable
      t.references :supplier, foreign_key: true
      t.string :event_type, null: false
      t.inet :ip
      t.string :user_agent
      t.jsonb :metadata, default: {}, null: false
      t.datetime :created_at, null: false
    end

    add_index :supplier_audit_events, :event_type
    add_index :supplier_audit_events, :created_at
  end
end
```

### Paso 7 — Migration: `create_supplier_invoices`

```ruby
# frozen_string_literal: true

class CreateSupplierInvoices < ActiveRecord::Migration[7.1]
  def change
    create_table :supplier_invoices do |t|
      t.references :supplier, null: false, foreign_key: true, index: true
      t.references :business_unit, null: false, foreign_key: true

      t.string :folio, null: false
      t.string :uuid_cfdi, null: false  # UUID del CFDI (SAT)

      t.date :fecha_recepcion, null: false
      t.date :fecha_vencimiento
      t.date :fecha_pago # programada o real

      t.decimal :monto_total,    precision: 14, scale: 2, null: false
      t.decimal :monto_pagado,   precision: 14, scale: 2, default: 0, null: false
      t.string  :moneda,         null: false, default: 'MXN'

      t.string :metodo_pago, null: false # 'PUE' | 'PPD'
      t.string :forma_pago               # catálogo SAT: '01', '03', etc.

      t.string :estatus, null: false, default: 'pending_match'
      # pending_match | in_review | approved | rejected | scheduled |
      # partially_paid | paid | cancelled

      t.string :purchase_order_number  # texto libre (Fase 1)
      t.string :numero_recepcion
      t.text   :rejection_note

      t.references :uploaded_by_supplier_user,
                   foreign_key: { to_table: :supplier_users }
      t.references :approved_by, foreign_key: { to_table: :users }
      t.references :rejected_by, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :supplier_invoices, :uuid_cfdi, unique: true
    add_index :supplier_invoices, :estatus
    add_index :supplier_invoices, [:supplier_id, :estatus]
  end
end
```

### Paso 8 — Migration: `create_payment_complements`

```ruby
# frozen_string_literal: true

class CreatePaymentComplements < ActiveRecord::Migration[7.1]
  def change
    create_table :payment_complements do |t|
      t.references :supplier_invoice, null: false, foreign_key: true, index: true
      t.references :supplier, null: false, foreign_key: true

      t.string :uuid_complemento, null: false
      t.date   :fecha_pago, null: false
      t.decimal :monto, precision: 14, scale: 2, null: false
      t.string :forma_pago_p # catálogo SAT del complemento

      t.references :uploaded_by_supplier_user,
                   foreign_key: { to_table: :supplier_users }

      t.timestamps
    end

    add_index :payment_complements, :uuid_complemento, unique: true
  end
end
```

### Paso 9 — Migration: `create_supplier_documents`

```ruby
# frozen_string_literal: true

class CreateSupplierDocuments < ActiveRecord::Migration[7.1]
  def change
    create_table :supplier_documents do |t|
      t.references :supplier, null: false, foreign_key: true
      t.references :attachable, polymorphic: true, null: false # invoice | complement
      t.string :kind, null: false # 'pdf' | 'xml'
      t.string :bucket, null: false
      t.string :path, null: false
      t.string :sha256, null: false
      t.bigint :byte_size, null: false
      t.references :uploaded_by_supplier_user,
                   foreign_key: { to_table: :supplier_users }

      t.timestamps
    end

    add_index :supplier_documents, [:attachable_type, :attachable_id]
    add_index :supplier_documents, [:supplier_id, :sha256], unique: true
    # ↑ evita duplicados del mismo archivo por mismo proveedor
  end
end
```

#### Aplicar todas las migrations pendientes

```bash
docker compose exec kumi_api bundle exec rails db:migrate
```

#### Verificación global

```bash
docker compose exec kumi_api bundle exec rails db:migrate:status | tail -20
```

Debes ver tus 6 migrations en estado `up`.

---

## Bloque C — Modelos

> Cada modelo es un paso. Voy a indicarte el contenido completo y la
> verificación. Por brevedad, los modelos más complejos van con todo
> el código; los simples van con la estructura mínima y referencia a
> patrones existentes en Kumi.

### Paso 10 — `app/models/supplier_user.rb`

Espejo de `ClientUser` adaptado a suppliers. **Lee `ClientUser`
primero** (`app/models/client_user.rb`) para entender el patrón.

```ruby
# frozen_string_literal: true

# SupplierUser — usuario del Portal de Proveedores.
# Cada proveedor (Supplier) puede tener varios SupplierUser.
# Auth: has_secure_password (bcrypt) + JWT propio.
# Patrón inspirado en ClientUser pero más simple (sin permisos
# granulares; un supplier_user solo ve sus propias facturas).
class SupplierUser < ApplicationRecord
  has_secure_password

  belongs_to :supplier
  belongs_to :business_unit
  has_many :supplier_user_tokens, dependent: :destroy
  has_many :supplier_audit_events
  has_many :uploaded_invoices, class_name: 'SupplierInvoice',
                                foreign_key: :uploaded_by_supplier_user_id

  validates :email, presence: true, uniqueness: true,
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :nombre, presence: true
  validates :jti, presence: true, uniqueness: true
  validates :password, length: { minimum: 12 }, if: -> { password.present? }

  before_validation :generate_jti, on: :create
  before_validation :assign_business_unit, on: :create

  scope :active,      -> { where(active: true) }
  scope :confirmed,   -> { where.not(confirmed_at: nil) }
  scope :unconfirmed, -> { where(confirmed_at: nil) }
  scope :locked,      -> { where.not(locked_at: nil) }

  # ── JWT ────────────────────────────────────────────────────
  def generate_jwt(exp = 12.hours.from_now)
    JWT.encode(
      { sub: id, supplier_id: supplier_id, jti: jti, exp: exp.to_i },
      Rails.application.secret_key_base, 'HS256'
    )
  end

  def revoke_jwt!
    update!(jti: SecureRandom.uuid)
  end

  # ── Lockable ───────────────────────────────────────────────
  def locked?
    locked_at.present? && locked_at > 1.hour.ago
  end

  def increment_failed_attempts!
    increment!(:failed_attempts)
    lock_access! if failed_attempts >= 5
  end

  def lock_access!
    update!(locked_at: Time.current,
            unlock_token: SecureRandom.urlsafe_base64)
  end

  def unlock!
    update!(locked_at: nil, unlock_token: nil, failed_attempts: 0)
  end

  # ── Confirmación ───────────────────────────────────────────
  def confirmed?
    confirmed_at.present?
  end

  def confirm!
    update!(confirmed_at: Time.current, active: true)
  end

  # ── Tracking ───────────────────────────────────────────────
  def track_sign_in(ip)
    update!(last_sign_in_at: Time.current,
            last_sign_in_ip: ip,
            sign_in_count: sign_in_count + 1)
  end

  private

  def generate_jti
    self.jti ||= SecureRandom.uuid
  end

  def assign_business_unit
    self.business_unit_id ||= supplier&.business_unit_id
  end
end
```

#### Verificación

```bash
docker compose exec kumi_api bundle exec rails runner "
  u = SupplierUser.new(email: 'test@x.com', nombre: 'Test',
                        password: 'Password123!!',
                        supplier: Supplier.first)
  puts u.valid? ? '✓ valid' : u.errors.full_messages.inspect
"
```

Debe imprimir `✓ valid`.

### Paso 11 — `app/models/supplier_user_token.rb`

```ruby
# frozen_string_literal: true

# SupplierUserToken — token efímero hashed para confirmación y reset.
# Nunca almacenes el token en claro. Solo el digest SHA256.
class SupplierUserToken < ApplicationRecord
  PURPOSES = %w[confirmation reset_password].freeze

  belongs_to :supplier_user

  validates :purpose, inclusion: { in: PURPOSES }
  validates :token_digest, presence: true, uniqueness: true
  validates :expires_at, presence: true

  scope :usable, -> { where(used_at: nil).where('expires_at > ?', Time.current) }

  # Genera un token raw + digest, y devuelve el raw (para el email).
  # El digest se guarda en BD; el raw NUNCA se persiste.
  def self.generate!(supplier_user:, purpose:, ttl:)
    raw = SecureRandom.urlsafe_base64(32)
    create!(
      supplier_user: supplier_user,
      purpose: purpose,
      token_digest: Digest::SHA256.hexdigest(raw),
      expires_at: ttl.from_now
    )
    raw
  end

  def self.consume!(raw_token, purpose:)
    digest = Digest::SHA256.hexdigest(raw_token)
    token = usable.where(purpose: purpose, token_digest: digest).first
    return nil unless token

    token.update!(used_at: Time.current)
    token
  end
end
```

### Paso 12 — `app/models/supplier_audit_event.rb`

```ruby
# frozen_string_literal: true

class SupplierAuditEvent < ApplicationRecord
  EVENT_TYPES = %w[
    login_success login_failed logout
    password_changed password_reset_requested password_reset_completed
    confirmation_sent confirmation_used
    account_locked account_unlocked forced_password_change
    invoice_uploaded invoice_cancelled complement_uploaded
  ].freeze

  belongs_to :supplier_user, optional: true
  belongs_to :supplier, optional: true

  validates :event_type, inclusion: { in: EVENT_TYPES }

  def self.track!(event_type:, supplier_user: nil, supplier: nil,
                  request: nil, metadata: {})
    create!(
      event_type: event_type,
      supplier_user: supplier_user,
      supplier: supplier || supplier_user&.supplier,
      ip: request&.remote_ip,
      user_agent: request&.user_agent,
      metadata: metadata
    )
  end
end
```

### Paso 13 — `app/models/supplier_invoice.rb`

```ruby
# frozen_string_literal: true

class SupplierInvoice < ApplicationRecord
  ESTATUS = %w[
    pending_match in_review approved rejected scheduled
    partially_paid paid cancelled
  ].freeze
  METODOS_PAGO = %w[PUE PPD].freeze

  belongs_to :supplier
  belongs_to :business_unit
  belongs_to :uploaded_by_supplier_user, class_name: 'SupplierUser',
                                          optional: true
  belongs_to :approved_by, class_name: 'User', optional: true
  belongs_to :rejected_by, class_name: 'User', optional: true

  has_many :payment_complements, dependent: :restrict_with_error
  has_many :supplier_documents, as: :attachable, dependent: :destroy

  validates :folio, presence: true
  validates :uuid_cfdi, presence: true, uniqueness: true
  validates :fecha_recepcion, presence: true
  validates :monto_total, presence: true, numericality: { greater_than: 0 }
  validates :metodo_pago, inclusion: { in: METODOS_PAGO }
  validates :estatus, inclusion: { in: ESTATUS }

  scope :pending_match, -> { where(estatus: 'pending_match') }
  scope :paid_or_partial, -> { where(estatus: %w[paid partially_paid]) }

  # Confirmación de pago: PUE = auto-confirmada; PPD = Σ complements == monto_pagado
  def confirmed_by_supplier?
    return true if metodo_pago == 'PUE' && estatus == 'paid'

    return false unless %w[paid partially_paid].include?(estatus)

    payment_complements.sum(:monto) >= monto_pagado
  end

  def needs_complement?
    metodo_pago == 'PPD' && monto_pagado.positive? && !confirmed_by_supplier?
  end
end
```

### Paso 14 — `app/models/payment_complement.rb`

```ruby
# frozen_string_literal: true

class PaymentComplement < ApplicationRecord
  belongs_to :supplier_invoice
  belongs_to :supplier
  belongs_to :uploaded_by_supplier_user, class_name: 'SupplierUser',
                                          optional: true
  has_many :supplier_documents, as: :attachable, dependent: :destroy

  validates :uuid_complemento, presence: true, uniqueness: true
  validates :fecha_pago, presence: true
  validates :monto, presence: true, numericality: { greater_than: 0 }

  # Al crear un complemento, actualiza el estatus de la factura.
  after_create :recalculate_invoice_status

  private

  def recalculate_invoice_status
    invoice = supplier_invoice
    invoice.monto_pagado += monto
    new_estatus = if invoice.monto_pagado >= invoice.monto_total
                    'paid'
                  else
                    'partially_paid'
                  end
    invoice.update!(monto_pagado: invoice.monto_pagado, estatus: new_estatus)
  end
end
```

### Paso 15 — `app/models/supplier_document.rb` + extender `Supplier`

`supplier_document.rb`:

```ruby
# frozen_string_literal: true

class SupplierDocument < ApplicationRecord
  KINDS = %w[pdf xml].freeze

  belongs_to :supplier
  belongs_to :attachable, polymorphic: true
  belongs_to :uploaded_by_supplier_user, class_name: 'SupplierUser',
                                          optional: true

  validates :kind, inclusion: { in: KINDS }
  validates :path, presence: true
  validates :sha256, presence: true

  def signed_download_url(ttl: 5.minutes)
    Storage::SupabaseStorageService.new.signed_download_url(path, ttl: ttl)
  end

  def self.build_path(supplier_id:, kind:, filename:)
    sanitized = filename.gsub(/[^\w.\-]/, '_').downcase
    now = Time.current
    "supplier_#{supplier_id}/#{now.strftime('%Y')}/#{now.strftime('%m')}/" \
      "#{kind}_#{SecureRandom.hex(4)}_#{sanitized}"
  end
end
```

Extiende `app/models/supplier.rb` agregando:

```ruby
has_many :supplier_users
has_many :supplier_invoices
has_many :payment_complements

# Estado del semáforo de confirmación
def confirmation_status
  paid = supplier_invoices.paid_or_partial
  return { color: :green, total_paid: 0, confirmed: 0,
           pending: 0, rate: 1.0 } if paid.empty?

  confirmed = paid.select(&:confirmed_by_supplier?).size
  rate = confirmed.to_f / paid.size

  pendings = paid.reject(&:confirmed_by_supplier?)
  old_pending = pendings.any? { |i| (Date.current - i.fecha_pago).to_i > 15 }
  medium_pending = pendings.any? { |i| (Date.current - i.fecha_pago).to_i > 7 }

  color = if rate < 0.7 || old_pending
            :red
          elsif rate < 1.0 || medium_pending
            :yellow
          else
            :green
          end

  { color: color, total_paid: paid.size, confirmed: confirmed,
    pending: pendings.size, rate: rate.round(2),
    pending_invoices: pendings.map(&:folio) }
end
```

#### Verificación del bloque C

```bash
docker compose exec kumi_api bundle exec rails runner "
  s = Supplier.first
  puts 'has_many supplier_users:', s.supplier_users.respond_to?(:to_a)
  puts 'confirmation_status:', s.confirmation_status.inspect
"
```

---

## Bloque D — Mailers

### Paso 16 — `app/mailers/portal/supplier_mailer.rb`

```bash
docker compose exec kumi_api bundle exec rails generate mailer \
  Portal::SupplierMailer confirmation reset_password account_locked
```

Reemplaza el contenido generado de `app/mailers/portal/supplier_mailer.rb`:

```ruby
# frozen_string_literal: true

class Portal::SupplierMailer < ApplicationMailer
  default from: 'no-reply@kumi.com'

  def confirmation(supplier_user, raw_token, temporary_password)
    @supplier_user = supplier_user
    @url = "#{portal_url}/confirmar?token=#{raw_token}"
    @temporary_password = temporary_password
    mail(to: supplier_user.email, subject: 'Activa tu cuenta — Portal de Proveedores TTPN')
  end

  def reset_password(supplier_user, raw_token)
    @supplier_user = supplier_user
    @url = "#{portal_url}/reset?token=#{raw_token}"
    mail(to: supplier_user.email, subject: 'Recuperación de contraseña — Portal TTPN')
  end

  def account_locked(supplier_user)
    @supplier_user = supplier_user
    mail(to: supplier_user.email, subject: 'Tu cuenta fue bloqueada por intentos fallidos')
  end

  private

  def portal_url
    ENV.fetch('PORTAL_PROVEEDORES_URL', 'http://localhost:9001')
  end
end
```

### Paso 17 — Templates HTML/text

Crea cada template con HTML simple (inline CSS, mobile-friendly).

`app/views/portal/supplier_mailer/confirmation.html.erb`:

```erb
<h2>¡Bienvenido a TTPN, <%= @supplier_user.nombre %>!</h2>
<p>Tu cuenta de proveedor ha sido creada. Para activarla, da click:</p>
<p><a href="<%= @url %>" style="background:#1976D2;color:#fff;
   padding:12px 24px;text-decoration:none;border-radius:4px;">
   Activar mi cuenta</a></p>
<p>Tu contraseña temporal es:</p>
<p style="font-family:monospace;font-size:18px;background:#f5f5f5;
   padding:8px 12px;border-radius:4px;"><%= @temporary_password %></p>
<p><strong>Al primer login se te pedirá cambiarla.</strong> El link
   de activación expira en 72 horas.</p>
<hr>
<small>Si no esperabas este correo, ignóralo. Equipo TTPN.</small>
```

Repite para `reset_password.html.erb` y `account_locked.html.erb` con
mensaje correspondiente. También crea las versiones `.text.erb` (texto
plano) para clientes de correo que no leen HTML.

### Paso 18 — Probar con `letter_opener`

Sigue las instrucciones de [manual_letter_opener.md](manual_letter_opener.md)
para abrir `http://localhost:3000/letter_opener` en una tab.

En otra tab, dentro de `rails console`:

```ruby
supplier = Supplier.first
user = SupplierUser.create!(
  supplier: supplier, email: 'prueba@test.com',
  nombre: 'Prueba', password: 'Tmp123456789!'
)
raw = SupplierUserToken.generate!(supplier_user: user, purpose: 'confirmation',
                                   ttl: 72.hours)
Portal::SupplierMailer.confirmation(user, raw, 'Tmp123456789!').deliver_now
```

Refresca `letter_opener` — debes ver el correo.

### Paso 19 — Servicio `Portal::ConfirmationService`

`app/services/portal/confirmation_service.rb`:

```ruby
# frozen_string_literal: true

# Genera password temporal + token de confirmación + manda email.
# Llamado desde el controller admin al crear un supplier_user.
class Portal::ConfirmationService
  def self.send_confirmation(supplier_user, request: nil)
    temp_password = SecureRandom.alphanumeric(16)
    supplier_user.password = temp_password
    supplier_user.password_confirmation = temp_password
    supplier_user.force_password_change = true
    supplier_user.save!

    raw = SupplierUserToken.generate!(
      supplier_user: supplier_user, purpose: 'confirmation', ttl: 72.hours
    )

    Portal::SupplierMailer.confirmation(supplier_user, raw, temp_password)
                          .deliver_later

    SupplierAuditEvent.track!(
      event_type: 'confirmation_sent', supplier_user: supplier_user,
      request: request
    )
  end
end
```

### Paso 20 — Servicio `Portal::PasswordResetService`

`app/services/portal/password_reset_service.rb`:

```ruby
# frozen_string_literal: true

class Portal::PasswordResetService
  def self.request_reset(email, request: nil)
    user = SupplierUser.find_by(email: email&.downcase)
    return unless user&.active? # responde 204 igual aunque no exista

    raw = SupplierUserToken.generate!(
      supplier_user: user, purpose: 'reset_password', ttl: 1.hour
    )
    Portal::SupplierMailer.reset_password(user, raw).deliver_later

    SupplierAuditEvent.track!(
      event_type: 'password_reset_requested',
      supplier_user: user, request: request
    )
  end

  def self.consume_reset(raw_token:, new_password:, request: nil)
    token = SupplierUserToken.consume!(raw_token, purpose: 'reset_password')
    return nil unless token

    user = token.supplier_user
    user.password = new_password
    user.password_confirmation = new_password
    user.failed_attempts = 0
    user.locked_at = nil
    user.save!

    SupplierAuditEvent.track!(
      event_type: 'password_reset_completed',
      supplier_user: user, request: request
    )
    user
  end
end
```

---

## Bloque E — JWT encoder/decoder

### Paso 21 — `app/services/portal/jwt_encoder.rb`

```ruby
# frozen_string_literal: true

module Portal
  class JwtEncoder
    def self.call(supplier_user)
      supplier_user.generate_jwt
    end
  end
end
```

### Paso 22 — `app/services/portal/jwt_decoder.rb`

```ruby
# frozen_string_literal: true

module Portal
  class JwtDecoder
    class InvalidToken < StandardError; end
    class ExpiredToken < StandardError; end
    class RevokedToken < StandardError; end

    def self.call(token)
      decoded = JWT.decode(token, Rails.application.secret_key_base,
                           true, algorithm: 'HS256').first
      user = SupplierUser.find(decoded['sub'])
      raise RevokedToken if decoded['jti'] != user.jti

      user
    rescue JWT::ExpiredSignature
      raise ExpiredToken
    rescue JWT::DecodeError, ActiveRecord::RecordNotFound
      raise InvalidToken
    end
  end
end
```

---

## Bloque F — Controllers del portal

### Paso 23 — `app/controllers/api/v1/portal/base_controller.rb`

```ruby
# frozen_string_literal: true

class Api::V1::Portal::BaseController < ActionController::API
  before_action :require_api_key!
  before_action :authenticate_supplier_user!

  attr_reader :current_supplier_user

  private

  # X-API-Key debe ser una key con scope al portal.
  def require_api_key!
    api_key = request.headers['X-API-Key']
    @api_key_record = ApiKey.authenticate(api_key) if api_key
    return if @api_key_record&.can?('supplier_portal', 'read')

    render json: { error: 'No autorizado' }, status: :unauthorized
  end

  def authenticate_supplier_user!
    auth = request.headers['Authorization']
    return render_unauth unless auth&.start_with?('Bearer ')

    token = auth.split(' ', 2).last
    @current_supplier_user = Portal::JwtDecoder.call(token)
    Current.supplier_user = @current_supplier_user if defined?(Current.supplier_user)
  rescue Portal::JwtDecoder::ExpiredToken
    render json: { error: 'Sesión expirada' }, status: :unauthorized
  rescue Portal::JwtDecoder::RevokedToken
    render json: { error: 'Token revocado' }, status: :unauthorized
  rescue Portal::JwtDecoder::InvalidToken
    render_unauth
  end

  def render_unauth
    render json: { error: 'Sesión expirada o inválida' }, status: :unauthorized
  end
end
```

> NOTA: para que `Current.supplier_user` exista, agrega
> `attribute :supplier_user` al `app/models/current.rb` existente.

### Paso 24 — Auth controller

`app/controllers/api/v1/portal/auth_controller.rb`:

```ruby
# frozen_string_literal: true

class Api::V1::Portal::AuthController < ActionController::API
  before_action :require_api_key!
  before_action :require_authenticated, only: [:logout]

  def login
    user = SupplierUser.find_by(email: params[:email]&.downcase)
    return reject('Credenciales inválidas') unless user
    return reject('Cuenta no confirmada') unless user.confirmed?
    return reject('Cuenta bloqueada', :locked) if user.locked?

    if user.authenticate(params[:password])
      user.reset_failed_attempts! if user.failed_attempts.positive?
      user.track_sign_in(request.remote_ip)
      track 'login_success', user
      render json: {
        jwt: user.generate_jwt,
        supplier_user: serialize(user),
        must_change_password: user.force_password_change
      }
    else
      user.increment_failed_attempts!
      track 'login_failed', user
      reject('Credenciales inválidas')
    end
  end

  def forgot_password
    Portal::PasswordResetService.request_reset(params[:email], request: request)
    head :no_content # 204 siempre — no revela si existe
  end

  def reset_password
    user = Portal::PasswordResetService.consume_reset(
      raw_token: params[:token],
      new_password: params[:password],
      request: request
    )
    return render(json: { error: 'Token inválido o expirado' },
                  status: :unauthorized) unless user

    render json: { jwt: user.generate_jwt, supplier_user: serialize(user) }
  end

  def confirm
    token = SupplierUserToken.consume!(params[:token], purpose: 'confirmation')
    return render(json: { error: 'Token inválido o expirado' },
                  status: :unauthorized) unless token

    user = token.supplier_user
    user.confirm!
    SupplierAuditEvent.track!(event_type: 'confirmation_used',
                              supplier_user: user, request: request)
    render json: { message: 'Cuenta activada. Inicia sesión.' }
  end

  def logout
    @current_supplier_user.revoke_jwt!
    track 'logout', @current_supplier_user
    head :no_content
  end

  private

  def require_api_key!
    api_key = request.headers['X-API-Key']
    record = ApiKey.authenticate(api_key)
    render json: { error: 'No autorizado' }, status: :unauthorized unless record
  end

  def require_authenticated
    # Reusamos lógica del BaseController para extraer el JWT
    auth = request.headers['Authorization']
    return render_unauth unless auth&.start_with?('Bearer ')

    @current_supplier_user = Portal::JwtDecoder.call(auth.split(' ', 2).last)
  rescue Portal::JwtDecoder::InvalidToken, Portal::JwtDecoder::ExpiredToken,
         Portal::JwtDecoder::RevokedToken
    render_unauth
  end

  def render_unauth
    render json: { error: 'Sesión expirada o inválida' }, status: :unauthorized
  end

  def reject(msg, status = :unauthorized)
    render json: { error: msg }, status: status
  end

  def track(event, user)
    SupplierAuditEvent.track!(event_type: event, supplier_user: user,
                              request: request)
  end

  def serialize(user)
    { id: user.id, email: user.email, nombre: user.nombre,
      supplier_id: user.supplier_id, supplier_name: user.supplier.nombre,
      force_password_change: user.force_password_change }
  end
end
```

### Paso 25 — `me` controller (cambio forzado de password)

`app/controllers/api/v1/portal/me_controller.rb`:

```ruby
# frozen_string_literal: true

class Api::V1::Portal::MeController < Api::V1::Portal::BaseController
  def change_password
    user = current_supplier_user
    return reject('Password actual incorrecta') unless user.authenticate(params[:current_password])

    user.password = params[:new_password]
    user.password_confirmation = params[:new_password]
    user.force_password_change = false
    if user.save
      SupplierAuditEvent.track!(event_type: 'password_changed',
                                supplier_user: user, request: request)
      render json: { message: 'Password actualizado' }
    else
      render json: { errors: user.errors.full_messages },
             status: :unprocessable_content
    end
  end

  private

  def reject(msg)
    render json: { error: msg }, status: :unprocessable_content
  end
end
```

### Paso 26 — Invoices controller

`app/controllers/api/v1/portal/invoices_controller.rb`:

```ruby
# frozen_string_literal: true

class Api::V1::Portal::InvoicesController < Api::V1::Portal::BaseController
  def index
    scope = current_supplier_user.supplier.supplier_invoices.order(created_at: :desc)
    scope = scope.where(estatus: params[:estatus]) if params[:estatus].present?
    scope = scope.where('fecha_recepcion >= ?', params[:from]) if params[:from].present?
    scope = scope.where('fecha_recepcion <= ?', params[:to]) if params[:to].present?

    render_paginated(scope) { |i| serialize(i) }
  end

  def show
    invoice = current_supplier_user.supplier.supplier_invoices.find(params[:id])
    render json: serialize(invoice, detailed: true)
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Factura no encontrada' }, status: :not_found
  end

  def bulk_upload
    # Recibe params[:invoices] como array de archivos PDF + XML
    # Solo crea las facturas en estado pending_match; el admin reconcilia después.
    # Por brevedad del manual, el dev implementa el detalle siguiendo
    # F3_bulk_upload_facturas.md.
    head :not_implemented # placeholder — ver flujos/F3_bulk_upload_facturas.md
  end

  def cancel
    invoice = current_supplier_user.supplier.supplier_invoices.find(params[:id])
    return reject('Solo se pueden cancelar facturas en pending_match') \
      unless invoice.estatus == 'pending_match'

    invoice.update!(estatus: 'cancelled')
    SupplierAuditEvent.track!(event_type: 'invoice_cancelled',
                              supplier_user: current_supplier_user,
                              request: request,
                              metadata: { invoice_id: invoice.id })
    head :no_content
  end

  private

  def render_paginated(scope)
    page = (params[:page] || 1).to_i
    per_page = (params[:per_page] || 20).to_i
    records = scope.page(page).per(per_page)
    render json: {
      data: records.map { |r| yield(r) },
      meta: { current_page: page, per_page: per_page,
              total_count: records.total_count,
              total_pages: records.total_pages }
    }
  end

  def serialize(inv, detailed: false)
    base = {
      id: inv.id, folio: inv.folio, uuid_cfdi: inv.uuid_cfdi,
      fecha_recepcion: inv.fecha_recepcion,
      fecha_vencimiento: inv.fecha_vencimiento,
      fecha_pago: inv.fecha_pago,
      monto_total: inv.monto_total, monto_pagado: inv.monto_pagado,
      moneda: inv.moneda, metodo_pago: inv.metodo_pago,
      estatus: inv.estatus, purchase_order_number: inv.purchase_order_number,
      numero_recepcion: inv.numero_recepcion
    }
    return base unless detailed

    base.merge(
      rejection_note: inv.rejection_note,
      documents: inv.supplier_documents.map { |d|
        { id: d.id, kind: d.kind, signed_url: d.signed_download_url }
      },
      complements: inv.payment_complements.map { |c|
        { id: c.id, uuid: c.uuid_complemento, fecha: c.fecha_pago, monto: c.monto }
      }
    )
  end

  def reject(msg)
    render json: { error: msg }, status: :unprocessable_content
  end
end
```

---

## Bloque G — Controllers admin de Kumi

Ver [kumi_admin_changes.md](kumi_admin_changes.md) para el detalle
completo. En síntesis se crean:

- `Api::V1::Suppliers::UsersController` (CRUD de supplier_users)
- `Api::V1::SupplierInvoicesController` (lista admin, aprobar, rechazar,
  programar pago, marcar OC)

Ambos heredan de `Api::V1::BaseController` (auth normal de User JWT) y
filtran por privilegio:

```ruby
before_action :authorize_finance!

private

def authorize_finance!
  return if current_user.sadmin? || can_for_module?('supplier_portal_users')

  render json: { error: 'Sin privilegio' }, status: :forbidden
end
```

---

## Bloque H — Routes + rate limiting

### Paso 33 — `config/routes/portal.rb`

```ruby
# frozen_string_literal: true

# Rutas del Portal de Proveedores. Toda /api/v1/portal/* requiere
# X-API-Key. Las que no son /auth/* requieren además JWT supplier_user.
namespace :portal do
  scope :auth do
    post  :login,           to: 'auth#login'
    post  :forgot_password, to: 'auth#forgot_password'
    post  :reset_password,  to: 'auth#reset_password'
    post  :confirm,         to: 'auth#confirm'
    post  :logout,          to: 'auth#logout'
  end

  scope :me do
    patch :password, to: 'me#change_password'
  end

  resources :invoices, only: [:index, :show] do
    collection { post :bulk_upload }
    member     { post :cancel }
  end

  resources :payments, only: [:index] do
    resources :complements, only: [:index, :create]
  end
end
```

Y en `config/routes.rb`, dentro del `namespace :v1`, agrega:

```ruby
draw :portal
```

### Paso 34 — Throttles rack-attack

Ver [seguridad.md](seguridad.md) sección "Rate limiting" para el
código exacto. Agrega al final de `config/initializers/rack_attack.rb`.

### Paso 35 — CORS

En Railway, agrega el dominio del portal a la variable
`FRONTEND_URL_EXTRA`. Nada en código.

---

## Bloque I — Tests

### Paso 36 — Spec del modelo `SupplierUser`

```bash
docker compose exec kumi_api bundle exec rails generate rspec:model SupplierUser
```

Contenido mínimo en `spec/models/supplier_user_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe SupplierUser, type: :model do
  let(:supplier) { create(:supplier) }
  subject { build(:supplier_user, supplier: supplier) }

  it { should validate_presence_of(:email) }
  it { should validate_uniqueness_of(:email) }
  it { should have_secure_password }

  describe '#generate_jwt' do
    it 'returns a decodable JWT' do
      subject.save!
      token = subject.generate_jwt
      decoded = JWT.decode(token, Rails.application.secret_key_base, true,
                           algorithm: 'HS256').first
      expect(decoded['sub']).to eq(subject.id)
    end
  end

  describe 'lockable' do
    it 'locks after 5 failed attempts' do
      subject.save!
      5.times { subject.increment_failed_attempts! }
      expect(subject.locked?).to be true
    end
  end
end
```

### Paso 37 — Specs de los controllers

Sigue el patrón existente de `spec/requests/api/v1/`. Cubre mínimo:

- `POST /portal/auth/login` con credenciales válidas → 200 + JWT.
- `POST /portal/auth/login` sin X-API-Key → 401.
- `POST /portal/auth/login` con password incorrecta 5 veces → cuenta `locked`.
- `GET /portal/invoices` sin JWT → 401.
- `GET /portal/invoices` con JWT de supplier A NO debe ver facturas de
  supplier B.

---

## Bloque J — Verificación end-to-end con curl

### Paso 38 — Crear ApiKey de prueba

```bash
docker compose exec kumi_api bundle exec rails runner "
  user = ApiUser.find_or_create_by!(
    email: 'portal-proveedores@kumi.local',
    business_unit: BusinessUnit.first,
    name: 'Portal Proveedores Dev',
    company_name: 'TTPN Dev'
  )
  key = ApiKey.generate_for_api_user(user, 'Portal Proveedores DEV', {
    'supplier_portal' => { 'read' => true, 'create' => true, 'update' => true }
  })
  puts \"X-API-Key: #{key.key}\"
"
```

Copia el `X-API-Key` impreso.

### Paso 39 — Crear un supplier_user de prueba

```bash
docker compose exec kumi_api bundle exec rails runner "
  s = Supplier.first
  u = SupplierUser.create!(
    supplier: s, email: 'prueba@x.com', nombre: 'Prueba',
    password: 'Tmp123456789!', confirmed_at: Time.current,
    force_password_change: false, active: true
  )
  puts u.id
"
```

### Paso 40 — Login con curl

```bash
curl -X POST http://localhost:3000/api/v1/portal/auth/login \
  -H "X-API-Key: <pega-tu-api-key>" \
  -H "Content-Type: application/json" \
  -d '{"email":"prueba@x.com","password":"Tmp123456789!"}'
```

Esperado: status 200 + JSON con `jwt`.

### Paso 41 — Listar facturas

```bash
curl http://localhost:3000/api/v1/portal/invoices \
  -H "X-API-Key: <api-key>" \
  -H "Authorization: Bearer <jwt-del-login>"
```

Esperado: 200 + `{ data: [], meta: {...} }` (vacío porque no hay
facturas todavía).

### Paso 42 — Flujo de confirmación

Ver [flujos/F1_alta_supplier_user.md](flujos/F1_alta_supplier_user.md)
para el end-to-end con LetterOpener.

---

## Checklist final del backend

- [ ] 6 migrations aplicadas (`db:migrate:status` todas `up`)
- [ ] 6 modelos con tests verde (`rspec spec/models/supplier*`)
- [ ] Mailers funcionan (LetterOpener muestra los 3 templates)
- [ ] `POST /portal/auth/login` responde 200 con JWT válido
- [ ] `GET /portal/invoices` responde con paginación
- [ ] `GET /portal/invoices` sin X-API-Key responde 401
- [ ] `SupplierAuditEvent` se crea en login_success / login_failed
- [ ] Rate limit funciona (6 logins fallidos seguidos → último responde 429)
- [ ] RuboCop 0 offenses en archivos nuevos
- [ ] RSpec ≥ 85 % de cobertura

---

## Siguiente paso

→ [manual_frontend.md](manual_frontend.md) — construir la PWA Quasar.
→ [kumi_admin_changes.md](kumi_admin_changes.md) — agregar el módulo
  admin dentro del menú Finanzas de Kumi.
