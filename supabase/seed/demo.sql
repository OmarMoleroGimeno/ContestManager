-- ============================================================================
--  Datos de demo — Conservatorio Demo
-- ============================================================================
--  NO es una migración. Vive fuera de supabase/migrations/ a propósito, para
--  que no se ejecute en ningún despliegue. Se lanza a mano cuando quieras
--  dejar la demo en un estado conocido.
--
--  Qué hace:
--    1. BORRA todos los concursos de la organización "Conservatorio Demo"
--       (irreversible: arrastra categorías, rondas, participantes, puntuaciones
--       y logs de auditoría). No toca ninguna otra organización.
--    2. Siembra 3 concursos: uno principal completo + uno en borrador + uno
--       finalizado.
--
--  Es idempotente: usa UUID fijos, así que re-ejecutarlo reproduce el mismo
--  estado exacto.
--
--  Copia de seguridad previa en supabase/seed/backup-conservatorio-demo-*.json
-- ============================================================================

begin;

-- ─── Guardia: aborta si falta alguna cuenta demo ────────────────────────────
-- Mejor fallar entero que dejar datos a medias.
do $$
declare
  faltan text;
begin
  select string_agg(e, ', ') into faltan
  from (values
    ('org@contestsaas.demo'), ('participante@contestsaas.demo'),
    ('jurado@contestsaas.demo'), ('juez1@contestsaas.demo'),
    ('juez2@contestsaas.demo'), ('juez3@contestsaas.demo')
  ) as v(e)
  where not exists (select 1 from auth.users u where u.email = v.e);

  if faltan is not null then
    raise exception 'Faltan cuentas demo en auth.users: %', faltan;
  end if;

  if not exists (select 1 from organizations where id = 'bbbbbbbb-0000-0000-0000-000000000001') then
    raise exception 'No existe la organización Conservatorio Demo';
  end if;
end $$;


-- ─── 1. Borrado ─────────────────────────────────────────────────────────────
-- El CASCADE se encarga de categorías → rondas → round_participants/scores/
-- score_criteria, y de participants → round_participants/scores.
-- billing_transactions.contest_id es ON DELETE SET NULL: el histórico de
-- facturación sobrevive, pero desconectado del concurso.
delete from contests
where organization_id = 'bbbbbbbb-0000-0000-0000-000000000001';


-- ─── 2. Concursos ───────────────────────────────────────────────────────────
insert into contests (
  id, organization_id, name, slug, description, rules, type, status,
  is_rounds_dynamic, starts_at, ends_at, registration_open, entry_fee_cents,
  cover_image_url, created_at
) values
-- Principal: activo, a media competición
('d0000000-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000001',
 'Certamen Nacional de Música 2026', 'certamen-nacional-2026',
 E'El **Certamen Nacional de Música 2026** reúne a jóvenes intérpretes de todo el país en tres especialidades: piano, canto lírico y violín.\n\nDurante una semana, un jurado formado por profesionales en activo evalúa a los aspirantes en sucesivas rondas eliminatorias hasta la gran final.\n\n- Sede: Auditorio del Conservatorio Municipal\n- Plazas limitadas por categoría\n- Premios en metálico y conciertos de temporada',
 E'## Reglamento\n\n**1. Inscripción.** Podrán inscribirse intérpretes que cumplan el rango de edad de su categoría a fecha 1 de enero de 2026. La organización se reserva el derecho de solicitar documento acreditativo.\n\n**2. Repertorio.** Cada aspirante presentará una obra obligatoria y una de libre elección. La duración total no excederá los 15 minutos.\n\n**3. Rondas.** El certamen se desarrolla en rondas eliminatorias. El jurado publicará los clasificados al término de cada ronda.\n\n**4. Jurado.** Sus decisiones son inapelables. Ningún miembro podrá evaluar a alumnos propios.\n\n**5. Ensayos.** Cada participante dispondrá de un ensayo con pianista acompañante en la sala asignada.\n\n**6. Devoluciones.** La cuota se reembolsa íntegramente hasta 15 días antes del comienzo.',
 'music', 'active', false,
 now() - interval '6 days', now() + interval '8 days', true, 2500,
 'https://thaftosvbwcoudzfwiou.supabase.co/storage/v1/object/public/contest-assets/default-cover.png',
 now() - interval '5 months'),

-- Apoyo: borrador (inscripciones desbloqueadas, botón "Iniciar concurso")
('d0000000-0000-0000-0000-000000000002', 'bbbbbbbb-0000-0000-0000-000000000001',
 'Concurso de Guitarra de Primavera 2027', 'guitarra-primavera-2027',
 E'Primera edición del concurso de guitarra clásica y flamenca. **En preparación** — las inscripciones aún no se han abierto al público.',
 null, 'music', 'draft', false,
 now() + interval '5 months', now() + interval '5 months 4 days', true, 1500,
 'https://thaftosvbwcoudzfwiou.supabase.co/storage/v1/object/public/contest-assets/default-cover.png',
 now() - interval '12 days'),

-- Apoyo: finalizado (da el segundo punto a la gráfica de crecimiento)
('d0000000-0000-0000-0000-000000000003', 'bbbbbbbb-0000-0000-0000-000000000001',
 'Certamen de Otoño 2025', 'certamen-otono-2025',
 E'Edición cerrada del certamen de otoño. Se conserva el histórico de participantes y resultados.',
 null, 'music', 'finished', false,
 now() - interval '11 months', now() - interval '11 months' + interval '5 days', false, 2000,
 'https://thaftosvbwcoudzfwiou.supabase.co/storage/v1/object/public/contest-assets/default-cover.png',
 now() - interval '12 months');


-- ─── 3. Categorías ──────────────────────────────────────────────────────────
-- Una por estado: active / closed / pending.
insert into categories (id, contest_id, name, description, "order", status, min_age, max_age, max_participants, artistic_type, speciality, created_at) values
('d1000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000001',
 'Piano Juvenil', 'Intérpretes de piano de 12 a 18 años. Obra obligatoria + libre.', 1, 'active', 12, 18, 20, 'Instrumental', 'Piano', now() - interval '5 months'),
('d1000000-0000-0000-0000-000000000002', 'd0000000-0000-0000-0000-000000000001',
 'Canto Lírico', 'Voces de 16 a 30 años. Aria de ópera y lied.', 2, 'closed', 16, 30, 16, 'Vocal', 'Canto', now() - interval '5 months'),
('d1000000-0000-0000-0000-000000000003', 'd0000000-0000-0000-0000-000000000001',
 'Violín Infantil', 'Iniciación al violín, de 8 a 12 años. Pendiente de comenzar.', 3, 'pending', 8, 12, 12, 'Instrumental', 'Violín', now() - interval '3 months'),
-- Apoyo
('d1000000-0000-0000-0000-000000000004', 'd0000000-0000-0000-0000-000000000002',
 'Guitarra Clásica', 'Categoría única, sin límite de edad.', 1, 'pending', null, null, 24, 'Instrumental', 'Guitarra', now() - interval '12 days'),
('d1000000-0000-0000-0000-000000000005', 'd0000000-0000-0000-0000-000000000003',
 'Piano Senior', 'Edición 2025, cerrada.', 1, 'closed', 18, 99, null, 'Instrumental', 'Piano', now() - interval '12 months');


-- ─── 4. Rondas ──────────────────────────────────────────────────────────────
-- OJO: el trigger block_round_start_if_contest_not_active rechaza una ronda
-- 'active' si el concurso padre no está 'active'. Por eso el concurso se
-- inserta antes, en esta misma transacción.
-- Índices únicos parciales: como máximo UNA ronda is_final y UNA is_ranking
-- por categoría.
insert into rounds (id, category_id, name, "order", status, scoring_type, max_score, is_final, is_ranking, is_published, started_at, closed_at, created_at) values
-- Piano Juvenil: una cerrada + una activa (el corazón de la demo)
('d2000000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000001',
 'Clasificatoria', 1, 'closed', 'numeric', 10, false, false, false,
 now() - interval '6 days', now() - interval '4 days', now() - interval '5 months'),
('d2000000-0000-0000-0000-000000000002', 'd1000000-0000-0000-0000-000000000001',
 'Semifinal', 2, 'active', 'numeric', 10, false, false, false,
 now() - interval '2 days', null, now() - interval '4 days'),
-- Canto Lírico: recorrido completo hasta ranking publicado
('d2000000-0000-0000-0000-000000000003', 'd1000000-0000-0000-0000-000000000002',
 'Clasificatoria', 1, 'closed', 'numeric', 10, false, false, false,
 now() - interval '6 days', now() - interval '5 days', now() - interval '5 months'),
('d2000000-0000-0000-0000-000000000004', 'd1000000-0000-0000-0000-000000000002',
 'Final', 2, 'closed', 'numeric', 10, true, false, false,
 now() - interval '4 days', now() - interval '3 days', now() - interval '5 days'),
('d2000000-0000-0000-0000-000000000005', 'd1000000-0000-0000-0000-000000000002',
 'Ranking', 3, 'closed', 'numeric', 10, false, true, true,
 null, now() - interval '3 days', now() - interval '3 days'),
-- Certamen de Otoño (finalizado)
('d2000000-0000-0000-0000-000000000006', 'd1000000-0000-0000-0000-000000000005',
 'Ronda Única', 1, 'closed', 'numeric', 10, true, false, false,
 now() - interval '11 months', now() - interval '11 months' + interval '2 days', now() - interval '12 months');
-- Violín Infantil (d1…003) y Guitarra Clásica (d1…004) se quedan SIN rondas
-- a propósito: así se ve la pantalla de configuración inicial.


-- ─── 5. Participantes ───────────────────────────────────────────────────────
-- El trigger _participants_backfill_name sobreescribe `name` con
-- first_name || ' ' || last_name, así que no se pasa `name`.
-- created_at repartido en varios meses: sin eso las gráficas de "Inscripciones
-- por mes" e "Ingresos mensuales" se quedan en su estado vacío.
insert into participants (
  id, contest_id, category_id, user_id, first_name, last_name, dni, birthdate,
  country, email, phone, status, payment_status, amount_paid_cents,
  amount_refunded_cents, refunded_at, stripe_payment_intent_id, created_at
) values
-- ── Piano Juvenil (10) ──
-- Ana García = cuenta demo de participante. Imprescindible mantener el user_id.
('d3000000-0000-0000-0000-000000000001','d0000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000001','aaaaaaaa-0000-0000-0000-000000000002',
 'Ana','García','12345678Z','2009-03-14','ES','participante@contestsaas.demo','+34600112233','active','paid',2500,0,null,'pi_demo_ana_0001', now() - interval '4 months'),
('d3000000-0000-0000-0000-000000000002','d0000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000001',null,
 'Mateo','Sánchez','23456789A','2008-11-02','ES','mateo.sanchez@example.com','+34611223344','active','paid',2500,0,null,'pi_demo_0002', now() - interval '4 months'),
('d3000000-0000-0000-0000-000000000003','d0000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000001',null,
 'Valentina','López','34567890B','2010-06-21','AR','valentina.lopez@example.com','+5491122334455','active','free',null,0,null,null, now() - interval '3 months'),
('d3000000-0000-0000-0000-000000000004','d0000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000001',null,
 'Hugo','Castillo','45678901C','2009-01-30','ES','hugo.castillo@example.com',null,'active','paid',2500,0,null,'pi_demo_0004', now() - interval '3 months'),
-- sin DNI y sin país: enseña los fallback de la tabla de inscripciones
('d3000000-0000-0000-0000-000000000005','d0000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000001',null,
 'Camila','Vargas',null,'2011-09-08',null,'camila.vargas@example.com','+34622334455','eliminated','pending',null,0,null,null, now() - interval '2 months'),
('d3000000-0000-0000-0000-000000000006','d0000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000001',null,
 'Diego','Navarro','56789012D','2008-04-17','ES','diego.navarro@example.com','+34633445566','active','paid',2500,0,null,'pi_demo_0006', now() - interval '2 months'),
-- reembolso completo
('d3000000-0000-0000-0000-000000000007','d0000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000001',null,
 'Elena','Ruiz','67890123E','2010-12-25','ES','elena.ruiz@example.com','+34644556677','eliminated','refunded',2500,2500, now() - interval '20 days','pi_demo_0007', now() - interval '2 months'),
-- reembolso parcial
('d3000000-0000-0000-0000-000000000008','d0000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000001',null,
 'Pablo','Jiménez','78901234F','2009-07-11','ES','pablo.jimenez@example.com','+34655667788','eliminated','partial_refund',2500,1000, now() - interval '12 days','pi_demo_0008', now() - interval '1 month'),
('d3000000-0000-0000-0000-000000000009','d0000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000001',null,
 'Natalia','Herrera','89012345G','2011-02-19','PT','natalia.herrera@example.com','+351912345678','eliminated','free',null,0,null,null, now() - interval '1 month'),
-- inscripción reciente: alimenta el contador "últimos 7 días"
('d3000000-0000-0000-0000-000000000010','d0000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000001',null,
 'Alejandro','Gómez','90123456H','2008-08-05','ES','alejandro.gomez@example.com','+34666778899','active','paid',2500,0,null,'pi_demo_0010', now() - interval '3 days'),

-- ── Canto Lírico (7) ──
('d3000000-0000-0000-0000-000000000011','d0000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000002',null,
 'Marta','Delgado','11223344J','2000-05-09','ES','marta.delgado@example.com','+34677889900','active','paid',2500,0,null,'pi_demo_0011', now() - interval '4 months'),
('d3000000-0000-0000-0000-000000000012','d0000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000002',null,
 'Javier','Ortega','22334455K','1998-10-23','ES','javier.ortega@example.com','+34688990011','active','paid',2500,0,null,'pi_demo_0012', now() - interval '4 months'),
('d3000000-0000-0000-0000-000000000013','d0000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000002',null,
 'Irene','Cabrera','33445566L','2002-01-15','MX','irene.cabrera@example.com',null,'active','free',null,0,null,null, now() - interval '3 months'),
('d3000000-0000-0000-0000-000000000014','d0000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000002',null,
 'Sergio','Peña','44556677M','1996-03-28','ES','sergio.pena@example.com','+34699001122','active','paid',2500,0,null,'pi_demo_0014', now() - interval '3 months'),
('d3000000-0000-0000-0000-000000000015','d0000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000002',null,
 'Nuria','Blanco','55667788N','2001-11-04','ES','nuria.blanco@example.com','+34610111213','eliminated','refunded',2500,2500, now() - interval '25 days','pi_demo_0015', now() - interval '2 months'),
('d3000000-0000-0000-0000-000000000016','d0000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000002',null,
 'Adrián','Soler','66778899P','1999-06-30','ES','adrian.soler@example.com','+34620212223','eliminated','paid',2500,0,null,'pi_demo_0016', now() - interval '2 months'),
('d3000000-0000-0000-0000-000000000017','d0000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000002',null,
 'Beatriz','Lara','77889900Q','2003-09-12','ES','beatriz.lara@example.com','+34630313233','eliminated','free',null,0,null,null, now() - interval '1 month'),

-- ── Violín Infantil (5) — categoría en configuración, sin rondas ──
('d3000000-0000-0000-0000-000000000018','d0000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000003',null,
 'Lucas','Prieto','88990011R','2015-04-02','ES','lucas.prieto@example.com','+34640414243','active','free',null,0,null,null, now() - interval '1 month'),
('d3000000-0000-0000-0000-000000000019','d0000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000003',null,
 'Emma','Rubio','99001122S','2016-08-19','ES','emma.rubio@example.com','+34650515253','active','paid',2500,0,null,'pi_demo_0019', now() - interval '20 days'),
('d3000000-0000-0000-0000-000000000020','d0000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000003',null,
 'Martín','Cano',null,'2014-12-07','ES','martin.cano@example.com',null,'active','pending',null,0,null,null, now() - interval '10 days'),
('d3000000-0000-0000-0000-000000000021','d0000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000003',null,
 'Sara','Vidal','10111213T','2015-02-14','FR','sara.vidal@example.com','+33612345678','active','free',null,0,null,null, now() - interval '6 days'),
('d3000000-0000-0000-0000-000000000022','d0000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000003',null,
 'Iker','Moya','12131415U','2016-05-26','ES','iker.moya@example.com','+34660616263','active','paid',2500,0,null,'pi_demo_0022', now() - interval '2 days'),

-- ── Guitarra (borrador, 4) ──
('d3000000-0000-0000-0000-000000000023','d0000000-0000-0000-0000-000000000002','d1000000-0000-0000-0000-000000000004',null,
 'Rocío','Ibáñez','13141516V','1995-07-03','ES','rocio.ibanez@example.com','+34670717273','active','free',null,0,null,null, now() - interval '10 days'),
('d3000000-0000-0000-0000-000000000024','d0000000-0000-0000-0000-000000000002','d1000000-0000-0000-0000-000000000004',null,
 'Tomás','Aguilar','14151617W','1992-02-28','ES','tomas.aguilar@example.com','+34680818283','active','free',null,0,null,null, now() - interval '9 days'),
('d3000000-0000-0000-0000-000000000025','d0000000-0000-0000-0000-000000000002','d1000000-0000-0000-0000-000000000004',null,
 'Alba','Ferrer','15161718X','1997-11-16','ES','alba.ferrer@example.com',null,'active','free',null,0,null,null, now() - interval '8 days'),
('d3000000-0000-0000-0000-000000000026','d0000000-0000-0000-0000-000000000002','d1000000-0000-0000-0000-000000000004',null,
 'Unai','Ramos','16171819Y','1994-09-21','ES','unai.ramos@example.com','+34690919293','active','free',null,0,null,null, now() - interval '5 days'),

-- ── Otoño 2025 (finalizado, 6) ──
('d3000000-0000-0000-0000-000000000027','d0000000-0000-0000-0000-000000000003','d1000000-0000-0000-0000-000000000005',null,
 'Clara','Montes','17181920Z','1990-01-12','ES','clara.montes@example.com','+34600102030','active','paid',2000,0,null,'pi_demo_0027', now() - interval '12 months'),
('d3000000-0000-0000-0000-000000000028','d0000000-0000-0000-0000-000000000003','d1000000-0000-0000-0000-000000000005',null,
 'Raúl','Esteban','18192021A','1988-04-08','ES','raul.esteban@example.com','+34600102031','active','paid',2000,0,null,'pi_demo_0028', now() - interval '12 months'),
('d3000000-0000-0000-0000-000000000029','d0000000-0000-0000-0000-000000000003','d1000000-0000-0000-0000-000000000005',null,
 'Silvia','Nieto','19202122B','1993-06-17','ES','silvia.nieto@example.com','+34600102032','eliminated','paid',2000,0,null,'pi_demo_0029', now() - interval '12 months'),
('d3000000-0000-0000-0000-000000000030','d0000000-0000-0000-0000-000000000003','d1000000-0000-0000-0000-000000000005',null,
 'Óscar','Lozano','20212223C','1991-10-29','ES','oscar.lozano@example.com','+34600102033','eliminated','paid',2000,0,null,'pi_demo_0030', now() - interval '11 months'),
('d3000000-0000-0000-0000-000000000031','d0000000-0000-0000-0000-000000000003','d1000000-0000-0000-0000-000000000005',null,
 'Paula','Vega','21222324D','1989-03-05','ES','paula.vega@example.com','+34600102034','eliminated','free',null,0,null,null, now() - interval '11 months'),
('d3000000-0000-0000-0000-000000000032','d0000000-0000-0000-0000-000000000003','d1000000-0000-0000-0000-000000000005',null,
 'Guillermo','Sanz','22232425E','1987-12-01','ES','guillermo.sanz@example.com','+34600102035','eliminated','refunded',2000,2000, now() - interval '11 months','pi_demo_0032', now() - interval '11 months');


-- ─── 6. Jurados del concurso ────────────────────────────────────────────────
-- El trigger set_judge_invitation_token fuerza invitation_status='pending' si
-- invitation_token viene NULL. Para sembrar un jurado ya aceptado hay que dar
-- el token explícitamente.
-- full_name se toma de profiles para que coincida con lo que ve el jurado al
-- iniciar sesión.
insert into contest_members (id, contest_id, user_id, email, full_name, role, invitation_status, invitation_token, invited_at, responded_at, created_at) values
('d6000000-0000-0000-0000-000000000001','d0000000-0000-0000-0000-000000000001','aaaaaaaa-0000-0000-0000-000000000001','org@contestsaas.demo','Organización Demo','organizer','accepted','tok_demo_org_0001', now() - interval '5 months', now() - interval '5 months', now() - interval '5 months'),
-- Carlos Jurado: la cuenta demo de jurado. Imprescindible que quede aceptada.
('d6000000-0000-0000-0000-000000000002','d0000000-0000-0000-0000-000000000001','aaaaaaaa-0000-0000-0000-000000000003','jurado@contestsaas.demo','Carlos Jurado','judge','accepted','tok_demo_jur_0002', now() - interval '4 months', now() - interval '4 months', now() - interval '4 months'),
('d6000000-0000-0000-0000-000000000003','d0000000-0000-0000-0000-000000000001','bbbbbbbb-0000-0000-0000-000000000001','juez1@contestsaas.demo','Carmen Vidal','judge','accepted','tok_demo_jur_0003', now() - interval '4 months', now() - interval '4 months', now() - interval '4 months'),
('d6000000-0000-0000-0000-000000000004','d0000000-0000-0000-0000-000000000001','bbbbbbbb-0000-0000-0000-000000000002','juez2@contestsaas.demo','Roberto Ruiz','judge','accepted','tok_demo_jur_0004', now() - interval '4 months', now() - interval '4 months', now() - interval '4 months'),
-- Invitación pendiente: enseña el estado "pendiente" y el botón de reenviar
('d6000000-0000-0000-0000-000000000005','d0000000-0000-0000-0000-000000000001','bbbbbbbb-0000-0000-0000-000000000003','juez3@contestsaas.demo','Lucía Fernández','judge','pending','tok_demo_jur_0005', now() - interval '3 days', null, now() - interval '3 days'),
-- Concursos de apoyo
('d6000000-0000-0000-0000-000000000006','d0000000-0000-0000-0000-000000000002','aaaaaaaa-0000-0000-0000-000000000001','org@contestsaas.demo','Organización Demo','organizer','accepted','tok_demo_org_0006', now() - interval '12 days', now() - interval '12 days', now() - interval '12 days'),
('d6000000-0000-0000-0000-000000000007','d0000000-0000-0000-0000-000000000003','aaaaaaaa-0000-0000-0000-000000000001','org@contestsaas.demo','Organización Demo','organizer','accepted','tok_demo_org_0007', now() - interval '12 months', now() - interval '12 months', now() - interval '12 months'),
('d6000000-0000-0000-0000-000000000008','d0000000-0000-0000-0000-000000000003','aaaaaaaa-0000-0000-0000-000000000003','jurado@contestsaas.demo','Carlos Jurado','judge','accepted','tok_demo_jur_0008', now() - interval '12 months', now() - interval '12 months', now() - interval '12 months');


-- ─── 7. Participantes por ronda ─────────────────────────────────────────────
-- is_qualified NULL = sin veredicto todavía. Solo se rellena en rondas
-- cerradas: en las activas debe seguir NULL o la UI diría "Eliminado" sin que
-- nadie haya puntuado.
-- rehearsal_time / performance_time son TEXT (datetime-local). Son el ÚNICO
-- origen de los eventos del calendario.
insert into round_participants (id, round_id, participant_id, "order", is_qualified, rehearsal_room, rehearsal_time, rehearsal_accompanist, performance_time, created_at) values
-- Piano · Clasificatoria (cerrada): 6 pasan, 4 caen
('d4000000-0000-0000-0000-000000000001','d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000001',1,true, 'Sala 1', to_char(now() - interval '6 days','YYYY-MM-DD')||'T09:00','Marta Ríos', to_char(now() - interval '6 days','YYYY-MM-DD')||'T16:00', now() - interval '7 days'),
('d4000000-0000-0000-0000-000000000002','d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000002',2,true, 'Sala 1', to_char(now() - interval '6 days','YYYY-MM-DD')||'T09:30','Marta Ríos', to_char(now() - interval '6 days','YYYY-MM-DD')||'T16:20', now() - interval '7 days'),
('d4000000-0000-0000-0000-000000000003','d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000003',3,true, 'Sala 1', to_char(now() - interval '6 days','YYYY-MM-DD')||'T10:00','Marta Ríos', to_char(now() - interval '6 days','YYYY-MM-DD')||'T16:40', now() - interval '7 days'),
('d4000000-0000-0000-0000-000000000004','d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000004',4,true, 'Sala 2', to_char(now() - interval '6 days','YYYY-MM-DD')||'T10:30','Iván Soto', to_char(now() - interval '6 days','YYYY-MM-DD')||'T17:00', now() - interval '7 days'),
('d4000000-0000-0000-0000-000000000005','d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000005',5,false,'Sala 2', to_char(now() - interval '6 days','YYYY-MM-DD')||'T11:00','Iván Soto', to_char(now() - interval '6 days','YYYY-MM-DD')||'T17:20', now() - interval '7 days'),
('d4000000-0000-0000-0000-000000000006','d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000006',6,true, 'Sala 2', to_char(now() - interval '6 days','YYYY-MM-DD')||'T11:30','Iván Soto', to_char(now() - interval '6 days','YYYY-MM-DD')||'T17:40', now() - interval '7 days'),
('d4000000-0000-0000-0000-000000000007','d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000007',7,false,'Sala 2', to_char(now() - interval '6 days','YYYY-MM-DD')||'T12:00','Iván Soto', to_char(now() - interval '6 days','YYYY-MM-DD')||'T18:00', now() - interval '7 days'),
('d4000000-0000-0000-0000-000000000008','d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000008',8,false,null,null,null,null, now() - interval '7 days'),
('d4000000-0000-0000-0000-000000000009','d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000009',9,false,null,null,null,null, now() - interval '7 days'),
('d4000000-0000-0000-0000-000000000010','d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000010',10,true,'Sala 1', to_char(now() - interval '6 days','YYYY-MM-DD')||'T12:30','Marta Ríos', to_char(now() - interval '6 days','YYYY-MM-DD')||'T18:20', now() - interval '7 days'),

-- Piano · Semifinal (ACTIVA): sin veredicto. Horarios próximos → calendario.
-- Dos sin horario a propósito, para ver también ese estado.
('d4000000-0000-0000-0000-000000000011','d2000000-0000-0000-0000-000000000002','d3000000-0000-0000-0000-000000000001',1,null,'Sala Principal', to_char(now() + interval '1 day','YYYY-MM-DD')||'T10:00','Marta Ríos', to_char(now() + interval '2 days','YYYY-MM-DD')||'T17:00', now() - interval '4 days'),
('d4000000-0000-0000-0000-000000000012','d2000000-0000-0000-0000-000000000002','d3000000-0000-0000-0000-000000000002',2,null,'Sala Principal', to_char(now() + interval '1 day','YYYY-MM-DD')||'T10:40','Marta Ríos', to_char(now() + interval '2 days','YYYY-MM-DD')||'T17:25', now() - interval '4 days'),
('d4000000-0000-0000-0000-000000000013','d2000000-0000-0000-0000-000000000002','d3000000-0000-0000-0000-000000000003',3,null,'Sala Principal', to_char(now() + interval '1 day','YYYY-MM-DD')||'T11:20','Iván Soto', to_char(now() + interval '2 days','YYYY-MM-DD')||'T17:50', now() - interval '4 days'),
('d4000000-0000-0000-0000-000000000014','d2000000-0000-0000-0000-000000000002','d3000000-0000-0000-0000-000000000004',4,null,'Sala Principal', to_char(now() + interval '1 day','YYYY-MM-DD')||'T12:00','Iván Soto', to_char(now() + interval '2 days','YYYY-MM-DD')||'T18:15', now() - interval '4 days'),
('d4000000-0000-0000-0000-000000000015','d2000000-0000-0000-0000-000000000002','d3000000-0000-0000-0000-000000000006',5,null,null,null,null,null, now() - interval '4 days'),
('d4000000-0000-0000-0000-000000000016','d2000000-0000-0000-0000-000000000002','d3000000-0000-0000-0000-000000000010',6,null,null,null,null,null, now() - interval '4 days'),

-- Canto · Clasificatoria (cerrada): 4 pasan, 3 caen
('d4000000-0000-0000-0000-000000000017','d2000000-0000-0000-0000-000000000003','d3000000-0000-0000-0000-000000000011',1,true, 'Sala 3', to_char(now() - interval '6 days','YYYY-MM-DD')||'T09:00','Elsa Marín', to_char(now() - interval '6 days','YYYY-MM-DD')||'T12:00', now() - interval '7 days'),
('d4000000-0000-0000-0000-000000000018','d2000000-0000-0000-0000-000000000003','d3000000-0000-0000-0000-000000000012',2,true, 'Sala 3', to_char(now() - interval '6 days','YYYY-MM-DD')||'T09:30','Elsa Marín', to_char(now() - interval '6 days','YYYY-MM-DD')||'T12:20', now() - interval '7 days'),
('d4000000-0000-0000-0000-000000000019','d2000000-0000-0000-0000-000000000003','d3000000-0000-0000-0000-000000000013',3,true, 'Sala 3', to_char(now() - interval '6 days','YYYY-MM-DD')||'T10:00','Elsa Marín', to_char(now() - interval '6 days','YYYY-MM-DD')||'T12:40', now() - interval '7 days'),
('d4000000-0000-0000-0000-000000000020','d2000000-0000-0000-0000-000000000003','d3000000-0000-0000-0000-000000000014',4,true, 'Sala 3', to_char(now() - interval '6 days','YYYY-MM-DD')||'T10:30','Elsa Marín', to_char(now() - interval '6 days','YYYY-MM-DD')||'T13:00', now() - interval '7 days'),
('d4000000-0000-0000-0000-000000000021','d2000000-0000-0000-0000-000000000003','d3000000-0000-0000-0000-000000000015',5,false,null,null,null,null, now() - interval '7 days'),
('d4000000-0000-0000-0000-000000000022','d2000000-0000-0000-0000-000000000003','d3000000-0000-0000-0000-000000000016',6,false,null,null,null,null, now() - interval '7 days'),
('d4000000-0000-0000-0000-000000000023','d2000000-0000-0000-0000-000000000003','d3000000-0000-0000-0000-000000000017',7,false,null,null,null,null, now() - interval '7 days'),

-- Canto · Final (cerrada): gana Marta
('d4000000-0000-0000-0000-000000000024','d2000000-0000-0000-0000-000000000004','d3000000-0000-0000-0000-000000000011',1,true, 'Auditorio', to_char(now() - interval '4 days','YYYY-MM-DD')||'T17:00','Elsa Marín', to_char(now() - interval '4 days','YYYY-MM-DD')||'T20:00', now() - interval '5 days'),
('d4000000-0000-0000-0000-000000000025','d2000000-0000-0000-0000-000000000004','d3000000-0000-0000-0000-000000000012',2,false,'Auditorio', to_char(now() - interval '4 days','YYYY-MM-DD')||'T17:30','Elsa Marín', to_char(now() - interval '4 days','YYYY-MM-DD')||'T20:20', now() - interval '5 days'),
('d4000000-0000-0000-0000-000000000026','d2000000-0000-0000-0000-000000000004','d3000000-0000-0000-0000-000000000013',3,false,'Auditorio', to_char(now() - interval '4 days','YYYY-MM-DD')||'T18:00','Elsa Marín', to_char(now() - interval '4 days','YYYY-MM-DD')||'T20:40', now() - interval '5 days'),
('d4000000-0000-0000-0000-000000000027','d2000000-0000-0000-0000-000000000004','d3000000-0000-0000-0000-000000000014',4,false,'Auditorio', to_char(now() - interval '4 days','YYYY-MM-DD')||'T18:30','Elsa Marín', to_char(now() - interval '4 days','YYYY-MM-DD')||'T21:00', now() - interval '5 days'),

-- Canto · Ranking (publicado)
('d4000000-0000-0000-0000-000000000028','d2000000-0000-0000-0000-000000000005','d3000000-0000-0000-0000-000000000011',1,true, null,null,null,null, now() - interval '3 days'),
('d4000000-0000-0000-0000-000000000029','d2000000-0000-0000-0000-000000000005','d3000000-0000-0000-0000-000000000012',2,false,null,null,null,null, now() - interval '3 days'),
('d4000000-0000-0000-0000-000000000030','d2000000-0000-0000-0000-000000000005','d3000000-0000-0000-0000-000000000013',3,false,null,null,null,null, now() - interval '3 days'),
('d4000000-0000-0000-0000-000000000031','d2000000-0000-0000-0000-000000000005','d3000000-0000-0000-0000-000000000014',4,false,null,null,null,null, now() - interval '3 days'),

-- Otoño 2025 · Ronda única
('d4000000-0000-0000-0000-000000000032','d2000000-0000-0000-0000-000000000006','d3000000-0000-0000-0000-000000000027',1,true, null,null,null,null, now() - interval '11 months'),
('d4000000-0000-0000-0000-000000000033','d2000000-0000-0000-0000-000000000006','d3000000-0000-0000-0000-000000000028',2,true, null,null,null,null, now() - interval '11 months'),
('d4000000-0000-0000-0000-000000000034','d2000000-0000-0000-0000-000000000006','d3000000-0000-0000-0000-000000000029',3,false,null,null,null,null, now() - interval '11 months'),
('d4000000-0000-0000-0000-000000000035','d2000000-0000-0000-0000-000000000006','d3000000-0000-0000-0000-000000000030',4,false,null,null,null,null, now() - interval '11 months'),
('d4000000-0000-0000-0000-000000000036','d2000000-0000-0000-0000-000000000006','d3000000-0000-0000-0000-000000000031',5,false,null,null,null,null, now() - interval '11 months'),
('d4000000-0000-0000-0000-000000000037','d2000000-0000-0000-0000-000000000006','d3000000-0000-0000-0000-000000000032',6,false,null,null,null,null, now() - interval '11 months');

-- Override de nota final con notas: se ve tachado el promedio y en morado el
-- valor forzado, en la Semifinal de Piano.
update round_participants set
  final_score_override = 9.20,
  final_score_override_by = 'aaaaaaaa-0000-0000-0000-000000000001',
  final_score_override_at = now() - interval '1 day',
  final_score_override_notes = 'Se corrige al alza tras revisar la grabación: un jurado no oyó la repetición de la coda.'
where id = 'd4000000-0000-0000-0000-000000000012';


-- ─── 8. Puntuaciones ────────────────────────────────────────────────────────
-- scores.judge_id → auth.users NOT NULL: solo jurados que existan de verdad.
-- Jurados: Carlos (aaaa…0003), Carmen (bbbb…0001), Roberto (bbbb…0002).
insert into scores (id, round_id, participant_id, judge_id, value, notes, promote, set_by_admin, admin_user_id, submitted_at, created_at)
select
  ('d5000000-0000-0000-0000-' || lpad((row_number() over ())::text, 12, '0'))::uuid,
  v.round_id::uuid, v.participant_id::uuid, v.judge_id::uuid,
  v.value, v.notes, v.promote, false, null,
  now() - interval '5 days', now() - interval '5 days'
from (values
  -- Piano · Clasificatoria (cerrada) — 10 participantes × 3 jurados
  ('d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000001','aaaaaaaa-0000-0000-0000-000000000003',9.0,'Musicalidad notable, pedal algo generoso.',true),
  ('d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000001','bbbbbbbb-0000-0000-0000-000000000001',9.5,'Excelente control dinámico.',true),
  ('d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000001','bbbbbbbb-0000-0000-0000-000000000002',8.8,null,true),
  ('d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000002','aaaaaaaa-0000-0000-0000-000000000003',8.5,'Buen fraseo.',true),
  ('d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000002','bbbbbbbb-0000-0000-0000-000000000001',8.0,null,false),
  ('d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000002','bbbbbbbb-0000-0000-0000-000000000002',8.7,'Sólido.',true),
  ('d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000003','aaaaaaaa-0000-0000-0000-000000000003',7.8,null,false),
  ('d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000003','bbbbbbbb-0000-0000-0000-000000000001',8.2,'Afinación cuidada.',true),
  ('d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000003','bbbbbbbb-0000-0000-0000-000000000002',7.9,null,false),
  ('d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000004','aaaaaaaa-0000-0000-0000-000000000003',8.9,'Gran presencia escénica.',true),
  ('d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000004','bbbbbbbb-0000-0000-0000-000000000001',8.4,null,true),
  ('d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000004','bbbbbbbb-0000-0000-0000-000000000002',9.1,'Muy maduro para su edad.',true),
  ('d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000005','aaaaaaaa-0000-0000-0000-000000000003',5.5,'Inseguridad en el desarrollo.',false),
  ('d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000005','bbbbbbbb-0000-0000-0000-000000000001',6.0,null,false),
  ('d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000005','bbbbbbbb-0000-0000-0000-000000000002',5.8,null,false),
  ('d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000006','aaaaaaaa-0000-0000-0000-000000000003',8.3,null,true),
  ('d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000006','bbbbbbbb-0000-0000-0000-000000000001',8.6,'Buen sentido del tempo.',true),
  ('d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000006','bbbbbbbb-0000-0000-0000-000000000002',8.1,null,true),
  ('d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000007','aaaaaaaa-0000-0000-0000-000000000003',6.2,null,false),
  ('d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000007','bbbbbbbb-0000-0000-0000-000000000001',5.9,'Repertorio por debajo del nivel.',false),
  ('d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000007','bbbbbbbb-0000-0000-0000-000000000002',6.4,null,false),
  ('d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000008','aaaaaaaa-0000-0000-0000-000000000003',6.8,null,false),
  ('d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000008','bbbbbbbb-0000-0000-0000-000000000001',7.0,null,false),
  ('d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000008','bbbbbbbb-0000-0000-0000-000000000002',6.5,'Le falta rodaje.',false),
  ('d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000009','aaaaaaaa-0000-0000-0000-000000000003',6.9,null,false),
  ('d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000009','bbbbbbbb-0000-0000-0000-000000000001',7.1,null,false),
  ('d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000009','bbbbbbbb-0000-0000-0000-000000000002',6.6,null,false),
  ('d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000010','aaaaaaaa-0000-0000-0000-000000000003',8.7,'Programa muy bien construido.',true),
  ('d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000010','bbbbbbbb-0000-0000-0000-000000000001',9.2,null,true),
  ('d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000010','bbbbbbbb-0000-0000-0000-000000000002',8.9,'Uno de los mejores de la ronda.',true),

  -- Piano · Semifinal (ACTIVA) — a medias a propósito:
  -- Carmen ha puntuado a los 6; Carlos solo a 3; Roberto a ninguno.
  -- Así el jurado demo entra y tiene 3 pendientes que puntuar en vivo.
  ('d2000000-0000-0000-0000-000000000002','d3000000-0000-0000-0000-000000000001','bbbbbbbb-0000-0000-0000-000000000001',9.3,'Mantiene el nivel.',true),
  ('d2000000-0000-0000-0000-000000000002','d3000000-0000-0000-0000-000000000002','bbbbbbbb-0000-0000-0000-000000000001',8.6,null,true),
  ('d2000000-0000-0000-0000-000000000002','d3000000-0000-0000-0000-000000000003','bbbbbbbb-0000-0000-0000-000000000001',8.1,null,false),
  ('d2000000-0000-0000-0000-000000000002','d3000000-0000-0000-0000-000000000004','bbbbbbbb-0000-0000-0000-000000000001',8.8,'Crecido desde la clasificatoria.',true),
  ('d2000000-0000-0000-0000-000000000002','d3000000-0000-0000-0000-000000000006','bbbbbbbb-0000-0000-0000-000000000001',8.4,null,true),
  ('d2000000-0000-0000-0000-000000000002','d3000000-0000-0000-0000-000000000010','bbbbbbbb-0000-0000-0000-000000000001',9.0,null,true),
  ('d2000000-0000-0000-0000-000000000002','d3000000-0000-0000-0000-000000000001','aaaaaaaa-0000-0000-0000-000000000003',9.1,'Confirma lo visto en la primera ronda.',true),
  ('d2000000-0000-0000-0000-000000000002','d3000000-0000-0000-0000-000000000002','aaaaaaaa-0000-0000-0000-000000000003',8.4,null,true),
  ('d2000000-0000-0000-0000-000000000002','d3000000-0000-0000-0000-000000000003','aaaaaaaa-0000-0000-0000-000000000003',7.9,'Nervios en el segundo movimiento.',false),

  -- Canto · Clasificatoria (cerrada)
  ('d2000000-0000-0000-0000-000000000003','d3000000-0000-0000-0000-000000000011','aaaaaaaa-0000-0000-0000-000000000003',9.4,'Proyección excepcional.',true),
  ('d2000000-0000-0000-0000-000000000003','d3000000-0000-0000-0000-000000000011','bbbbbbbb-0000-0000-0000-000000000001',9.6,null,true),
  ('d2000000-0000-0000-0000-000000000003','d3000000-0000-0000-0000-000000000012','aaaaaaaa-0000-0000-0000-000000000003',8.7,null,true),
  ('d2000000-0000-0000-0000-000000000003','d3000000-0000-0000-0000-000000000012','bbbbbbbb-0000-0000-0000-000000000001',8.9,'Buena dicción.',true),
  ('d2000000-0000-0000-0000-000000000003','d3000000-0000-0000-0000-000000000013','aaaaaaaa-0000-0000-0000-000000000003',8.2,null,true),
  ('d2000000-0000-0000-0000-000000000003','d3000000-0000-0000-0000-000000000013','bbbbbbbb-0000-0000-0000-000000000001',8.0,null,true),
  ('d2000000-0000-0000-0000-000000000003','d3000000-0000-0000-0000-000000000014','aaaaaaaa-0000-0000-0000-000000000003',8.5,'Registro grave muy sólido.',true),
  ('d2000000-0000-0000-0000-000000000003','d3000000-0000-0000-0000-000000000014','bbbbbbbb-0000-0000-0000-000000000001',8.3,null,true),
  ('d2000000-0000-0000-0000-000000000003','d3000000-0000-0000-0000-000000000015','aaaaaaaa-0000-0000-0000-000000000003',6.5,null,false),
  ('d2000000-0000-0000-0000-000000000003','d3000000-0000-0000-0000-000000000015','bbbbbbbb-0000-0000-0000-000000000001',6.2,'Afinación irregular.',false),
  ('d2000000-0000-0000-0000-000000000003','d3000000-0000-0000-0000-000000000016','aaaaaaaa-0000-0000-0000-000000000003',6.9,null,false),
  ('d2000000-0000-0000-0000-000000000003','d3000000-0000-0000-0000-000000000016','bbbbbbbb-0000-0000-0000-000000000001',7.1,null,false),
  ('d2000000-0000-0000-0000-000000000003','d3000000-0000-0000-0000-000000000017','aaaaaaaa-0000-0000-0000-000000000003',6.0,null,false),
  ('d2000000-0000-0000-0000-000000000003','d3000000-0000-0000-0000-000000000017','bbbbbbbb-0000-0000-0000-000000000001',6.3,null,false),

  -- Canto · Final (cerrada)
  ('d2000000-0000-0000-0000-000000000004','d3000000-0000-0000-0000-000000000011','aaaaaaaa-0000-0000-0000-000000000003',9.7,'Ganadora indiscutible.',true),
  ('d2000000-0000-0000-0000-000000000004','d3000000-0000-0000-0000-000000000011','bbbbbbbb-0000-0000-0000-000000000001',9.8,null,true),
  ('d2000000-0000-0000-0000-000000000004','d3000000-0000-0000-0000-000000000012','aaaaaaaa-0000-0000-0000-000000000003',9.0,null,false),
  ('d2000000-0000-0000-0000-000000000004','d3000000-0000-0000-0000-000000000012','bbbbbbbb-0000-0000-0000-000000000001',8.8,null,false),
  ('d2000000-0000-0000-0000-000000000004','d3000000-0000-0000-0000-000000000013','aaaaaaaa-0000-0000-0000-000000000003',8.4,null,false),
  ('d2000000-0000-0000-0000-000000000004','d3000000-0000-0000-0000-000000000013','bbbbbbbb-0000-0000-0000-000000000001',8.6,null,false),
  ('d2000000-0000-0000-0000-000000000004','d3000000-0000-0000-0000-000000000014','aaaaaaaa-0000-0000-0000-000000000003',8.9,null,false),
  ('d2000000-0000-0000-0000-000000000004','d3000000-0000-0000-0000-000000000014','bbbbbbbb-0000-0000-0000-000000000001',8.7,null,false),

  -- Otoño 2025 (finalizado)
  ('d2000000-0000-0000-0000-000000000006','d3000000-0000-0000-0000-000000000027','aaaaaaaa-0000-0000-0000-000000000003',9.1,null,true),
  ('d2000000-0000-0000-0000-000000000006','d3000000-0000-0000-0000-000000000028','aaaaaaaa-0000-0000-0000-000000000003',8.8,null,true),
  ('d2000000-0000-0000-0000-000000000006','d3000000-0000-0000-0000-000000000029','aaaaaaaa-0000-0000-0000-000000000003',7.2,null,false),
  ('d2000000-0000-0000-0000-000000000006','d3000000-0000-0000-0000-000000000030','aaaaaaaa-0000-0000-0000-000000000003',6.8,null,false),
  ('d2000000-0000-0000-0000-000000000006','d3000000-0000-0000-0000-000000000031','aaaaaaaa-0000-0000-0000-000000000003',6.4,null,false),
  ('d2000000-0000-0000-0000-000000000006','d3000000-0000-0000-0000-000000000032','aaaaaaaa-0000-0000-0000-000000000003',5.9,null,false)
) as v(round_id, participant_id, judge_id, value, notes, promote);

-- Una nota modificada por el admin: sale resaltada y con el badge
-- "Modificado por admin" en la tabla de puntuaciones.
update scores set
  value = 8.60,
  set_by_admin = true,
  admin_user_id = 'aaaaaaaa-0000-0000-0000-000000000001',
  notes = 'Ajustada por la organización tras la reclamación del participante.',
  updated_at = now() - interval '1 day'
where round_id = 'd2000000-0000-0000-0000-000000000002'
  and participant_id = 'd3000000-0000-0000-0000-000000000003'
  and judge_id = 'aaaaaaaa-0000-0000-0000-000000000003';


-- ─── 9. Historial de auditoría ──────────────────────────────────────────────
-- Alimenta la pestaña de auditoría de la ronda.
insert into score_audit_logs (id, round_id, participant_id, judge_id, changed_by, changed_by_name, action, old_value, new_value, notes, is_admin_action, created_at) values
('d7000000-0000-0000-0000-000000000001','d2000000-0000-0000-0000-000000000002','d3000000-0000-0000-0000-000000000003','aaaaaaaa-0000-0000-0000-000000000003','aaaaaaaa-0000-0000-0000-000000000003','Carlos Jurado','score_created',null,7.90,'Nervios en el segundo movimiento.',false, now() - interval '2 days'),
('d7000000-0000-0000-0000-000000000002','d2000000-0000-0000-0000-000000000002','d3000000-0000-0000-0000-000000000003','aaaaaaaa-0000-0000-0000-000000000003','aaaaaaaa-0000-0000-0000-000000000001','Organización Demo','score_updated',7.90,8.60,'Ajustada por la organización tras la reclamación del participante.',true, now() - interval '1 day'),
('d7000000-0000-0000-0000-000000000003','d2000000-0000-0000-0000-000000000002','d3000000-0000-0000-0000-000000000002',null,'aaaaaaaa-0000-0000-0000-000000000001','Organización Demo','override_set',null,9.20,'Se corrige al alza tras revisar la grabación: un jurado no oyó la repetición de la coda.',true, now() - interval '1 day');


-- ─── 10. Nombres del pool de jurados ────────────────────────────────────────
-- La tabla `judges` traía nombres que no coincidían con `profiles` (juez1 era
-- "María Fernández" en judges y "Carmen Vidal" en profiles). Se alinean para
-- que la demo sea coherente entre la pantalla de Jurados y lo que ve cada
-- jurado al iniciar sesión.
update judges set full_name = 'Carmen Vidal',     specialty = 'Piano'        where email = 'juez1@contestsaas.demo';
update judges set full_name = 'Roberto Ruiz',     specialty = 'Repertorio'   where email = 'juez2@contestsaas.demo';
update judges set full_name = 'Lucía Fernández',  specialty = null           where email = 'juez3@contestsaas.demo';
update judges set full_name = 'Sergio Mendoza',   specialty = 'Canto'        where email = 'juez4@contestsaas.demo';
update judges set full_name = 'Carlos Jurado',    specialty = 'Jazz'         where email = 'jurado@contestsaas.demo';


-- ─── 9bis. Otoño 2025: mesa de 4 jurados e historial de cambios ─────────────
-- El concurso finalizado tenía un solo jurado y cero auditoría, así que su
-- panel REGISTRO salía con "Sin cambios registrados aún.".
-- Los jurados tienen que ser cuentas reales de auth.users con perfil: el
-- endpoint de auditoría resuelve `judge_name` desde `profiles.full_name`.
insert into contest_members (id, contest_id, user_id, email, full_name, role, invitation_status, invitation_token, invited_at, responded_at, created_at) values
('d6000000-0000-0000-0000-000000000009','d0000000-0000-0000-0000-000000000003','bbbbbbbb-0000-0000-0000-000000000001','juez1@contestsaas.demo','Carmen Vidal','judge','accepted','tok_demo_jur_0009', now() - interval '12 months', now() - interval '12 months', now() - interval '12 months'),
('d6000000-0000-0000-0000-000000000010','d0000000-0000-0000-0000-000000000003','bbbbbbbb-0000-0000-0000-000000000002','juez2@contestsaas.demo','Roberto Ruiz','judge','accepted','tok_demo_jur_0010', now() - interval '12 months', now() - interval '12 months', now() - interval '12 months'),
('d6000000-0000-0000-0000-000000000011','d0000000-0000-0000-0000-000000000003','bbbbbbbb-0000-0000-0000-000000000004','juez4@contestsaas.demo','Sergio Mendoza','judge','accepted','tok_demo_jur_0011', now() - interval '12 months', now() - interval '12 months', now() - interval '12 months');

insert into scores (id, round_id, participant_id, judge_id, value, notes, promote, set_by_admin, admin_user_id, submitted_at, created_at)
select ('d5000000-0000-0000-0000-1' || lpad((row_number() over ())::text, 11, '0'))::uuid,
       'd2000000-0000-0000-0000-000000000006'::uuid, v.p::uuid, v.j::uuid, v.val, v.nt, v.pr, false, null,
       now() - interval '11 months', now() - interval '11 months'
from (values
('d3000000-0000-0000-0000-000000000027','bbbbbbbb-0000-0000-0000-000000000001',9.3,'Programa exigente resuelto con solvencia.',true),
('d3000000-0000-0000-0000-000000000027','bbbbbbbb-0000-0000-0000-000000000002',8.9,null,true),
('d3000000-0000-0000-0000-000000000027','bbbbbbbb-0000-0000-0000-000000000004',9.0,'Fraseo maduro.',true),
('d3000000-0000-0000-0000-000000000028','bbbbbbbb-0000-0000-0000-000000000001',8.6,null,true),
('d3000000-0000-0000-0000-000000000028','bbbbbbbb-0000-0000-0000-000000000002',9.0,'Muy buen sentido del rubato.',true),
('d3000000-0000-0000-0000-000000000028','bbbbbbbb-0000-0000-0000-000000000004',8.7,null,true),
('d3000000-0000-0000-0000-000000000029','bbbbbbbb-0000-0000-0000-000000000001',7.5,null,false),
('d3000000-0000-0000-0000-000000000029','bbbbbbbb-0000-0000-0000-000000000002',7.0,'Irregular en el segundo movimiento.',false),
('d3000000-0000-0000-0000-000000000029','bbbbbbbb-0000-0000-0000-000000000004',7.4,null,false),
('d3000000-0000-0000-0000-000000000030','bbbbbbbb-0000-0000-0000-000000000001',7.0,null,false),
('d3000000-0000-0000-0000-000000000030','bbbbbbbb-0000-0000-0000-000000000002',6.5,null,false),
('d3000000-0000-0000-0000-000000000030','bbbbbbbb-0000-0000-0000-000000000004',6.9,'Le pesa el repertorio.',false),
('d3000000-0000-0000-0000-000000000031','bbbbbbbb-0000-0000-0000-000000000001',6.6,null,false),
('d3000000-0000-0000-0000-000000000031','bbbbbbbb-0000-0000-0000-000000000002',6.2,null,false),
('d3000000-0000-0000-0000-000000000031','bbbbbbbb-0000-0000-0000-000000000004',6.5,null,false),
('d3000000-0000-0000-0000-000000000032','bbbbbbbb-0000-0000-0000-000000000001',6.1,'Nervios evidentes desde el inicio.',false),
('d3000000-0000-0000-0000-000000000032','bbbbbbbb-0000-0000-0000-000000000002',5.7,null,false),
('d3000000-0000-0000-0000-000000000032','bbbbbbbb-0000-0000-0000-000000000004',6.0,null,false)
) as v(p,j,val,nt,pr);

-- El estado final de cada nota debe coincidir con lo que cuenta el registro.
update scores set value=9.1, set_by_admin=true, admin_user_id='aaaaaaaa-0000-0000-0000-000000000001',
  notes='Corregida por la organización tras revisar la grabación.'
where round_id='d2000000-0000-0000-0000-000000000006' and participant_id='d3000000-0000-0000-0000-000000000027' and judge_id='aaaaaaaa-0000-0000-0000-000000000003';
update scores set value=7.0, set_by_admin=true, admin_user_id='aaaaaaaa-0000-0000-0000-000000000001',
  notes='Ajuste tras reclamación del participante.'
where round_id='d2000000-0000-0000-0000-000000000006' and participant_id='d3000000-0000-0000-0000-000000000029' and judge_id='bbbbbbbb-0000-0000-0000-000000000002';
update scores set value=6.0, set_by_admin=true, admin_user_id='aaaaaaaa-0000-0000-0000-000000000001',
  notes='El jurado transcribió mal la nota en su acta.'
where round_id='d2000000-0000-0000-0000-000000000006' and participant_id='d3000000-0000-0000-0000-000000000032' and judge_id='bbbbbbbb-0000-0000-0000-000000000004';

-- Override que se conserva (Raúl Esteban). El de Óscar Lozano se puso y se
-- retiró, así que él termina SIN override: el registro lo cuenta, el dato no.
update round_participants set final_score_override=9.00,
  final_score_override_by='aaaaaaaa-0000-0000-0000-000000000001',
  final_score_override_at= now() - interval '11 months' + interval '2 days',
  final_score_override_notes='Bonificación por obra obligatoria de dificultad superior, acordada por el comité.'
where round_id='d2000000-0000-0000-0000-000000000006' and participant_id='d3000000-0000-0000-0000-000000000028';

-- Historial. Solo estos cuatro valores de `action` se traducen en pantalla:
-- score_set / score_updated / override_set / override_removed. Cualquier otro
-- saldría en crudo. `is_admin_action` es lo que pinta el punto morado y la
-- insignia ADMIN que distingue a la organización del jurado.
insert into score_audit_logs (id, round_id, participant_id, judge_id, changed_by, changed_by_name, action, old_value, new_value, notes, is_admin_action, created_at) values
('d7000000-0000-0000-0000-000000000011','d2000000-0000-0000-0000-000000000006','d3000000-0000-0000-0000-000000000027','aaaaaaaa-0000-0000-0000-000000000003','aaaaaaaa-0000-0000-0000-000000000003','Carlos Jurado','score_set',null,8.70,'Sólido, aunque irregular en la coda.',false, now() - interval '11 months'),
('d7000000-0000-0000-0000-000000000012','d2000000-0000-0000-0000-000000000006','d3000000-0000-0000-0000-000000000027','bbbbbbbb-0000-0000-0000-000000000001','bbbbbbbb-0000-0000-0000-000000000001','Carmen Vidal','score_set',null,9.30,'Programa exigente resuelto con solvencia.',false, now() - interval '11 months' + interval '35 minutes'),
('d7000000-0000-0000-0000-000000000013','d2000000-0000-0000-0000-000000000006','d3000000-0000-0000-0000-000000000028','bbbbbbbb-0000-0000-0000-000000000002','bbbbbbbb-0000-0000-0000-000000000002','Roberto Ruiz','score_set',null,9.00,'Muy buen sentido del rubato.',false, now() - interval '11 months' + interval '1 hour 10 minutes'),
('d7000000-0000-0000-0000-000000000014','d2000000-0000-0000-0000-000000000006','d3000000-0000-0000-0000-000000000032','bbbbbbbb-0000-0000-0000-000000000004','bbbbbbbb-0000-0000-0000-000000000004','Sergio Mendoza','score_set',null,5.00,null,false, now() - interval '11 months' + interval '2 hours'),
('d7000000-0000-0000-0000-000000000015','d2000000-0000-0000-0000-000000000006','d3000000-0000-0000-0000-000000000027','aaaaaaaa-0000-0000-0000-000000000003','aaaaaaaa-0000-0000-0000-000000000001','Organización Demo','score_updated',8.70,9.10,'Corregida por la organización tras revisar la grabación.',true, now() - interval '11 months' + interval '1 day'),
('d7000000-0000-0000-0000-000000000016','d2000000-0000-0000-0000-000000000006','d3000000-0000-0000-0000-000000000032','bbbbbbbb-0000-0000-0000-000000000004','aaaaaaaa-0000-0000-0000-000000000001','Organización Demo','score_updated',5.00,6.00,'El jurado transcribió mal la nota en su acta.',true, now() - interval '11 months' + interval '1 day 1 hour'),
('d7000000-0000-0000-0000-000000000017','d2000000-0000-0000-0000-000000000006','d3000000-0000-0000-0000-000000000029','bbbbbbbb-0000-0000-0000-000000000002','aaaaaaaa-0000-0000-0000-000000000001','Organización Demo','score_updated',6.40,7.00,'Ajuste tras reclamación del participante.',true, now() - interval '11 months' + interval '1 day 3 hours'),
('d7000000-0000-0000-0000-000000000018','d2000000-0000-0000-0000-000000000006','d3000000-0000-0000-0000-000000000030',null,'aaaaaaaa-0000-0000-0000-000000000001','Organización Demo','override_set',null,7.50,'Revisión provisional a la espera del informe del jurado.',true, now() - interval '11 months' + interval '1 day 6 hours'),
('d7000000-0000-0000-0000-000000000019','d2000000-0000-0000-0000-000000000006','d3000000-0000-0000-0000-000000000030',null,'aaaaaaaa-0000-0000-0000-000000000001','Organización Demo','override_removed',7.50,null,'Retirada: el informe confirma la media original.',true, now() - interval '11 months' + interval '1 day 20 hours'),
('d7000000-0000-0000-0000-000000000020','d2000000-0000-0000-0000-000000000006','d3000000-0000-0000-0000-000000000028',null,'aaaaaaaa-0000-0000-0000-000000000001','Organización Demo','override_set',null,9.00,'Bonificación por obra obligatoria de dificultad superior, acordada por el comité.',true, now() - interval '11 months' + interval '2 days');


-- ─── 10bis. Reparto de los ingresos en el tiempo ────────────────────────────
-- La gráfica "Ingresos mensuales" del dashboard sale de billing_transactions
-- con reason='purchase_bundle' (compras de packs de tickets), NO de las cuotas
-- de los participantes. Todas las compras estaban en un único mes, así que la
-- gráfica caía en su estado vacío ("Los ingresos aparecerán cuando vendas
-- tickets"). Se reparten en cuatro meses SIN inventar importes: se mueven las
-- fechas de las compras que ya existían.
with ordered as (
  select id, row_number() over (order by created_at) as rn
  from billing_transactions
  where organization_id = 'bbbbbbbb-0000-0000-0000-000000000001'
    and reason = 'purchase_bundle' and entity = 'ticket'
)
update billing_transactions b
set created_at = case o.rn
      when 1 then now() - interval '7 months'
      when 2 then now() - interval '5 months'
      when 3 then now() - interval '3 months'
      else        now() - interval '1 month'
    end
from ordered o
where b.id = o.id;


-- ─── 11. Limpieza de notificaciones ─────────────────────────────────────────
-- Los triggers notify_org_participant_added / _removed generan una
-- notificación al dueño por CADA participante insertado o borrado. Sin esto la
-- campana aparece con decenas de avisos de ruido en plena demo.
-- También se limpian las que apuntaban a concursos ya borrados (notifications
-- no tiene FK a contests: la referencia va por JSONB).
delete from notifications
where user_id in (
  'aaaaaaaa-0000-0000-0000-000000000001', -- Organización Demo
  'aaaaaaaa-0000-0000-0000-000000000002', -- Ana García
  'aaaaaaaa-0000-0000-0000-000000000003', -- Carlos Jurado
  'bbbbbbbb-0000-0000-0000-000000000001', -- Carmen Vidal
  'bbbbbbbb-0000-0000-0000-000000000002', -- Roberto Ruiz
  'bbbbbbbb-0000-0000-0000-000000000003'  -- Lucía Fernández
);

-- Y en su lugar, unas pocas coherentes con el estado sembrado, para que la
-- campana tenga algo real que enseñar.
insert into notifications (id, user_id, type, title, body, payload, read, created_at) values
-- Organizador
('d9000000-0000-0000-0000-000000000001','aaaaaaaa-0000-0000-0000-000000000001','org_participant_enrolled',
 'Nueva inscripción','Iker Moya se ha inscrito en Violín Infantil.',
 jsonb_build_object('contest_id','d0000000-0000-0000-0000-000000000001','contest_slug','certamen-nacional-2026'), false, now() - interval '2 days'),
('d9000000-0000-0000-0000-000000000002','aaaaaaaa-0000-0000-0000-000000000001','org_participant_enrolled',
 'Nueva inscripción','Alejandro Gómez se ha inscrito en Piano Juvenil.',
 jsonb_build_object('contest_id','d0000000-0000-0000-0000-000000000001','contest_slug','certamen-nacional-2026'), false, now() - interval '3 days'),
('d9000000-0000-0000-0000-000000000003','aaaaaaaa-0000-0000-0000-000000000001','ranking_published',
 'Ranking publicado','Ya está publicada la clasificación final de Canto Lírico.',
 jsonb_build_object('contest_id','d0000000-0000-0000-0000-000000000001','contest_slug','certamen-nacional-2026'), true, now() - interval '3 days'),
-- Jurado demo
('d9000000-0000-0000-0000-000000000004','aaaaaaaa-0000-0000-0000-000000000003','round_started',
 'Semifinal en marcha','La Semifinal de Piano Juvenil ya admite puntuaciones.',
 jsonb_build_object('contest_id','d0000000-0000-0000-0000-000000000001','contest_slug','certamen-nacional-2026'), false, now() - interval '2 days'),
-- Participante demo
('d9000000-0000-0000-0000-000000000005','aaaaaaaa-0000-0000-0000-000000000002','participant_qualified',
 '¡Has pasado a la Semifinal!','Enhorabuena Ana, has superado la Clasificatoria de Piano Juvenil.',
 jsonb_build_object('contest_id','d0000000-0000-0000-0000-000000000001','contest_slug','certamen-nacional-2026'), false, now() - interval '4 days'),
('d9000000-0000-0000-0000-000000000006','aaaaaaaa-0000-0000-0000-000000000002','schedule_assigned',
 'Tienes horario de ensayo','Sala Principal, mañana. Consulta tu calendario.',
 jsonb_build_object('contest_id','d0000000-0000-0000-0000-000000000001','contest_slug','certamen-nacional-2026'), false, now() - interval '1 day');

commit;
