-- ═══════════════════════════════════════════════════════
-- SAPMS: Three-School Setup
-- Step 1: Rename Kivu Hills Academy → ES Tyazo
-- Step 2: Add GS St Paul Tyazo + classes + 200 students
-- ═══════════════════════════════════════════════════════

START TRANSACTION;

-- ── STEP 1: Rename Kivu Hills Academy → ES Tyazo ─────
UPDATE schools SET
  name = 'ES Tyazo',
  code = 'NS-EST'
WHERE id = '8b5c6cf4-d82c-46af-891e-97868b09f27e';

-- Update user school references (teachers, admins, parents)
-- (users.school_id already references the id, not the code, so no change needed)

-- ── STEP 2: Create GS St Paul Tyazo ──────────────────
INSERT INTO schools (id, name, code) VALUES
  ('379882db-953c-44f7-85d1-d13eb4a0fa31', 'GS St Paul Tyazo', 'NS-SPT');

-- ── STEP 3: Classes for GS St Paul Tyazo ─────────────
INSERT INTO classes (id, school_id, name, level, academic_year_id) VALUES
  ('7a8acb87-d766-4b6c-8f4c-2ba2612eca0c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 'S1-A', 'S1', '1617323c-1630-43e1-bdfd-7d837aac88b3');
INSERT INTO classes (id, school_id, name, level, academic_year_id) VALUES
  ('aea4518a-7edd-405e-a303-50bd84994245', '379882db-953c-44f7-85d1-d13eb4a0fa31', 'S2-A', 'S2', '1617323c-1630-43e1-bdfd-7d837aac88b3');
INSERT INTO classes (id, school_id, name, level, academic_year_id) VALUES
  ('a8a721fd-9545-402b-8cd7-4014e6e7246c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 'S3-A', 'S3', '1617323c-1630-43e1-bdfd-7d837aac88b3');
INSERT INTO classes (id, school_id, name, level, academic_year_id) VALUES
  ('4ccfccc6-b07c-4159-94df-eac73859c08d', '379882db-953c-44f7-85d1-d13eb4a0fa31', 'S4-PCM', 'S4', '1617323c-1630-43e1-bdfd-7d837aac88b3');
INSERT INTO classes (id, school_id, name, level, academic_year_id) VALUES
  ('8026f846-103a-4ff9-ba32-423b4e8896cd', '379882db-953c-44f7-85d1-d13eb4a0fa31', 'S5-PCB', 'S5', '1617323c-1630-43e1-bdfd-7d837aac88b3');

-- ── STEP 4: Insert 200 students for GS St Paul Tyazo ─
INSERT INTO students (id, student_code, name, gender, date_of_birth, class_id, school_id, is_active) VALUES
  ('fe7667f6-4004-4967-9923-3d850628185e', 'SPT0001', 'Ujeneza Thierry', 'F', '2008-06-07', '7a8acb87-d766-4b6c-8f4c-2ba2612eca0c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('8f93970f-a469-4810-8fd5-842fc35c197f', 'SPT0002', 'Christian Kwizera Shema', 'M', '2007-04-27', '7a8acb87-d766-4b6c-8f4c-2ba2612eca0c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('f45b3b7f-4adf-478f-a6a4-0ab1fa9a7ae3', 'SPT0003', 'Brian Nkuranga', 'M', '2006-05-16', '7a8acb87-d766-4b6c-8f4c-2ba2612eca0c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('745cbe6c-c67b-4f75-a233-907cbe872a2a', 'SPT0004', 'Ibtisam  Abdijamal', 'M', '2007-03-18', '7a8acb87-d766-4b6c-8f4c-2ba2612eca0c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('99bc7361-4c23-485c-916c-1cef25213fd2', 'SPT0005', 'Ishimwe Michee', 'F', '2006-05-01', '7a8acb87-d766-4b6c-8f4c-2ba2612eca0c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('1965e2c4-c52d-4b6b-ba35-031330c0d2b2', 'SPT0006', 'Arinze Evaristus', 'F', '2009-03-26', '7a8acb87-d766-4b6c-8f4c-2ba2612eca0c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('243e92d7-7d4d-479a-98e9-1ad28eee6468', 'SPT0007', 'Bahati Gapfizi Edgar', 'M', '2007-09-27', '7a8acb87-d766-4b6c-8f4c-2ba2612eca0c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('579b3a51-64bb-41aa-903c-8e57b9497ed9', 'SPT0008', 'Dusenge Clovis', 'F', '2009-03-11', '7a8acb87-d766-4b6c-8f4c-2ba2612eca0c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('29cb57ad-8a5e-4f0c-b88e-3d7319e78651', 'SPT0009', 'Tumukunde Henriette Mugisha', 'F', '2008-02-03', '7a8acb87-d766-4b6c-8f4c-2ba2612eca0c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('360993ff-5223-472f-99a9-84303803db8d', 'SPT0010', 'Gwiza Queen', 'F', '2008-09-16', '7a8acb87-d766-4b6c-8f4c-2ba2612eca0c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('78f8ee9c-df8c-49f0-bdc0-c2a3cf24a2e3', 'SPT0011', 'Nyiramahirwe Mucunda Nadine', 'F', '2007-04-07', '7a8acb87-d766-4b6c-8f4c-2ba2612eca0c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('455220f0-1aa2-4514-a5c5-671976e215dd', 'SPT0012', 'Gabriel Sebit Deng Tang', 'M', '2006-02-28', '7a8acb87-d766-4b6c-8f4c-2ba2612eca0c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('79b7cccf-7f19-48a4-84bc-0fc2ab7f3919', 'SPT0013', 'Mugisha Ishimwe Amede', 'F', '2007-12-18', '7a8acb87-d766-4b6c-8f4c-2ba2612eca0c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('832ee278-a6b1-4f25-b078-7a93e53a98d3', 'SPT0014', 'Uwubutatu Jean Paul', 'M', '2009-10-23', '7a8acb87-d766-4b6c-8f4c-2ba2612eca0c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('f6c29691-f654-42ca-a0ee-f73b62457ca6', 'SPT0015', 'Kalisa  Mugisha Fabrice', 'F', '2006-02-27', '7a8acb87-d766-4b6c-8f4c-2ba2612eca0c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('6236cbc3-b148-432d-a656-882578be1d26', 'SPT0016', 'Gisa Gatsinzi Queen', 'F', '2007-12-11', '7a8acb87-d766-4b6c-8f4c-2ba2612eca0c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('fd1ae4ba-d5f3-40ef-a8d1-80a350cb1b59', 'SPT0017', 'Mashengesho Denise', 'M', '2006-02-19', '7a8acb87-d766-4b6c-8f4c-2ba2612eca0c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('a49b907c-ed93-4f41-b141-d1e3e534449b', 'SPT0018', 'Mbarushimana Hirwa Alnaud', 'F', '2009-02-26', '7a8acb87-d766-4b6c-8f4c-2ba2612eca0c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('70245dbc-a534-4a4f-a560-327378e7d120', 'SPT0019', 'Ntwali  Prince Clovis', 'M', '2006-05-15', '7a8acb87-d766-4b6c-8f4c-2ba2612eca0c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('9da7b72c-3b26-41ca-baff-d2f0bfc355f4', 'SPT0020', 'Bwimba Mose', 'F', '2006-06-17', '7a8acb87-d766-4b6c-8f4c-2ba2612eca0c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('9e13f181-884a-472e-91db-1f0df2df3feb', 'SPT0021', 'Mwebaze Edwin', 'F', '2006-07-25', '7a8acb87-d766-4b6c-8f4c-2ba2612eca0c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('66fc74d3-509f-4ea9-aed9-c9a9b9f39972', 'SPT0022', 'Muhirwa Cedric', 'F', '2007-04-19', '7a8acb87-d766-4b6c-8f4c-2ba2612eca0c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('2780321d-795f-4d14-8960-a81dacbb9dac', 'SPT0023', 'Ndayishimiye Jean Paul', 'F', '2009-07-24', '7a8acb87-d766-4b6c-8f4c-2ba2612eca0c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('26d8e7f7-3e5d-4930-9314-3bb9bb55408b', 'SPT0024', 'Gislaine Ineza', 'F', '2007-07-01', '7a8acb87-d766-4b6c-8f4c-2ba2612eca0c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('e01965cd-0dfd-49f6-a21a-ea281bc7e18c', 'SPT0025', 'Ishimwe Marcellin', 'F', '2006-01-16', '7a8acb87-d766-4b6c-8f4c-2ba2612eca0c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('693e249e-f2b5-4505-9745-1f3efe0a81b1', 'SPT0026', 'Uwayo Daima', 'M', '2006-12-12', '7a8acb87-d766-4b6c-8f4c-2ba2612eca0c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('4fcb6d46-c3fa-410b-a22c-53f8ea26d5e9', 'SPT0027', 'Mvano Ange Nelly', 'M', '2009-02-09', '7a8acb87-d766-4b6c-8f4c-2ba2612eca0c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('ceedb428-c69f-45ef-9cdb-9b9a1ccf7f2d', 'SPT0028', 'Murasira Obed', 'F', '2009-01-21', '7a8acb87-d766-4b6c-8f4c-2ba2612eca0c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('bb9918a7-1218-4907-9213-e48bf3f469f4', 'SPT0029', 'Aline Ishimwe', 'F', '2009-12-21', '7a8acb87-d766-4b6c-8f4c-2ba2612eca0c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('9f0588fc-5f0a-4380-ba41-1f5d467c8345', 'SPT0030', 'Rwego Etienne', 'M', '2006-03-10', '7a8acb87-d766-4b6c-8f4c-2ba2612eca0c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('66e321f6-7f96-46b0-86bd-b6dfa5ff2eb3', 'SPT0031', 'Ingeneye Twagirayezu Benedict Cred', 'F', '2006-01-27', '7a8acb87-d766-4b6c-8f4c-2ba2612eca0c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('7defdd3b-4cbd-4457-8afb-deaf1cbcb8f5', 'SPT0032', 'Kamana Sulaimani Junior', 'F', '2009-06-27', '7a8acb87-d766-4b6c-8f4c-2ba2612eca0c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('bc3fdc06-1ab2-4c0c-9b64-88c58b80a6e9', 'SPT0033', 'Akaliza Desire Igeet', 'F', '2009-10-01', '7a8acb87-d766-4b6c-8f4c-2ba2612eca0c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('aa82ae24-2ea4-47a7-8e37-d3830045cab4', 'SPT0034', 'Cyubahiro Alain Fernando', 'M', '2006-08-05', '7a8acb87-d766-4b6c-8f4c-2ba2612eca0c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('3d1dc2f6-9e85-4071-aac0-56a11e6880ef', 'SPT0035', 'Divin Rukundo', 'M', '2006-12-01', '7a8acb87-d766-4b6c-8f4c-2ba2612eca0c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('af85020a-5963-4682-922c-6674a55cc9e1', 'SPT0036', 'Mugisha Delphin', 'F', '2007-02-22', '7a8acb87-d766-4b6c-8f4c-2ba2612eca0c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('06ce61e5-338e-40b5-9475-e2068f901677', 'SPT0037', 'Nziza Daniel', 'F', '2009-02-28', '7a8acb87-d766-4b6c-8f4c-2ba2612eca0c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('5b13be75-2dce-4d41-aabd-87a2f74bf2f6', 'SPT0038', 'Oda Nzayisenga', 'F', '2009-08-04', '7a8acb87-d766-4b6c-8f4c-2ba2612eca0c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('79c3ad8d-8dcf-4cc4-b45c-465ced4fac99', 'SPT0039', 'Uwituze Arlette Sunny', 'F', '2007-04-09', '7a8acb87-d766-4b6c-8f4c-2ba2612eca0c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('0b79e3ad-907d-4dbd-b2b9-c8ea094f662c', 'SPT0040', 'Ruzindana Shema Brian', 'F', '2007-02-06', '7a8acb87-d766-4b6c-8f4c-2ba2612eca0c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('bd98a9dc-e788-4549-b7dd-d22ecc46d8d6', 'SPT0041', 'Basel Salaheldeen Muhmedahmed Suliman', 'M', '2007-03-01', 'aea4518a-7edd-405e-a303-50bd84994245', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('98c0703f-6232-4fea-8a69-bc89e8cde314', 'SPT0042', 'Bahar  Tidjani Ach-Ary', 'M', '2006-04-22', 'aea4518a-7edd-405e-a303-50bd84994245', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('49f728dc-fc48-423d-a755-6cf72c04104b', 'SPT0043', 'Nshuti Yves', 'M', '2009-10-23', 'aea4518a-7edd-405e-a303-50bd84994245', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('ddcb64db-6cff-4ac1-b8b9-9b39a5f2cac9', 'SPT0044', 'Uwineza Kellia', 'F', '2009-08-17', 'aea4518a-7edd-405e-a303-50bd84994245', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('1315a998-49c5-4c24-b001-3ab1a4b3cacb', 'SPT0045', 'Shema Serge Benjamin', 'F', '2008-10-27', 'aea4518a-7edd-405e-a303-50bd84994245', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('eca1bf6d-6164-423a-adc7-b4765533c5c3', 'SPT0046', 'Irakoze  Gasasira Ange', 'F', '2006-08-20', 'aea4518a-7edd-405e-a303-50bd84994245', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('cb546bd1-d622-4168-b6f2-5af1bc3f2597', 'SPT0047', 'Ketia Rwakazina', 'F', '2009-05-18', 'aea4518a-7edd-405e-a303-50bd84994245', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('46afeaf2-0eb9-4f54-8cac-b9dc3c8b4baa', 'SPT0048', 'Umuganwa Annaick', 'F', '2008-05-15', 'aea4518a-7edd-405e-a303-50bd84994245', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('1ce4e516-3567-42da-9fb7-8becfcd435d6', 'SPT0049', 'Uwayo Abdul Alim', 'M', '2007-01-19', 'aea4518a-7edd-405e-a303-50bd84994245', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('c7c8958e-799e-4097-a5cb-fd8e1531988b', 'SPT0050', 'Adolphe Nshimiyimana', 'F', '2009-02-02', 'aea4518a-7edd-405e-a303-50bd84994245', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1);

INSERT INTO students (id, student_code, name, gender, date_of_birth, class_id, school_id, is_active) VALUES
  ('ebbfdfc1-25bb-40d4-b303-c892c487b9fb', 'SPT0051', 'Umuhire Leah', 'F', '2006-12-05', 'aea4518a-7edd-405e-a303-50bd84994245', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('f092edc6-8176-4175-8e2c-d9fa41ee1bb4', 'SPT0052', 'Maluiel Deng Kuat', 'M', '2006-02-22', 'aea4518a-7edd-405e-a303-50bd84994245', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('5a8479de-ac06-45f1-88c8-ea88949c0087', 'SPT0053', 'Musindikazi Eugenie', 'M', '2006-09-07', 'aea4518a-7edd-405e-a303-50bd84994245', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('169376be-8284-412a-8703-c7c699eb8422', 'SPT0054', 'Umubyeyi  Gloriose', 'M', '2006-07-06', 'aea4518a-7edd-405e-a303-50bd84994245', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('ebd61030-6d3a-4c17-b373-d0d6e61e2176', 'SPT0055', 'Breaud Kokoi Mahamat Marc', 'M', '2006-11-13', 'aea4518a-7edd-405e-a303-50bd84994245', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('ed8b16dd-9f9f-468d-9034-e9fbc89b9917', 'SPT0056', 'Ihabwicyubahiro Lachairoi', 'M', '2008-08-16', 'aea4518a-7edd-405e-a303-50bd84994245', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('c94d49df-5359-4e8e-8679-c8d17d02f5c5', 'SPT0057', 'Dukundane Emmanuel', 'F', '2009-04-27', 'aea4518a-7edd-405e-a303-50bd84994245', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('58d2c67c-d1cc-48ef-b9db-9bc6bf82f024', 'SPT0058', 'Ndagijimana Antoine', 'F', '2009-05-10', 'aea4518a-7edd-405e-a303-50bd84994245', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('c5077d34-8204-454a-8ba3-6d53bf972cca', 'SPT0059', 'Benjamin Irakomeye', 'M', '2006-09-11', 'aea4518a-7edd-405e-a303-50bd84994245', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('7dcde542-35a5-4473-8752-fbe3fc954de3', 'SPT0060', 'Makuac Patrick David  Woun', 'M', '2008-04-25', 'aea4518a-7edd-405e-a303-50bd84994245', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('7b1a4100-0cc1-4f3a-ac11-900b9750597e', 'SPT0061', 'Niyogushimwa Valentine', 'F', '2008-06-25', 'aea4518a-7edd-405e-a303-50bd84994245', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('1d4de6f1-414a-43a6-a805-4eb33e6039b6', 'SPT0062', 'Ingabire  Clementine', 'F', '2009-12-25', 'aea4518a-7edd-405e-a303-50bd84994245', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('60bb0554-2a4b-42f4-984c-f124fc4f245e', 'SPT0063', 'Forben Niba Branzel', 'M', '2009-09-18', 'aea4518a-7edd-405e-a303-50bd84994245', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('95839b6a-8571-4578-99b0-838c160ae82c', 'SPT0064', 'Chris Mbungiramihigo', 'M', '2009-05-13', 'aea4518a-7edd-405e-a303-50bd84994245', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('3e018e2f-2dce-4d12-8956-d5768e82ceb9', 'SPT0065', 'Hakizimana  Billy', 'F', '2008-02-09', 'aea4518a-7edd-405e-a303-50bd84994245', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('a9221494-87ff-4e33-b269-69f610620d15', 'SPT0066', 'Hirwa Yusuf', 'F', '2006-03-05', 'aea4518a-7edd-405e-a303-50bd84994245', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('97354a4c-267d-4716-8595-cac00a03a92d', 'SPT0067', 'Domenyo Komi Uel Tugli', 'M', '2008-12-02', 'aea4518a-7edd-405e-a303-50bd84994245', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('517fac3b-5d5f-4cb7-890a-e3cd6ea35fa3', 'SPT0068', 'Kahasha Pacifique', 'F', '2007-10-20', 'aea4518a-7edd-405e-a303-50bd84994245', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('2f3f3936-f553-4df4-8921-5d216cba968e', 'SPT0069', 'Anthony  M. Cassell Monyue', 'M', '2006-09-01', 'aea4518a-7edd-405e-a303-50bd84994245', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('3e563ce2-2c94-4a7d-912f-20d592787264', 'SPT0070', 'Akech Dut Kou Nhial', 'M', '2006-11-23', 'aea4518a-7edd-405e-a303-50bd84994245', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('1c96b949-ba22-4adb-8fb5-ed51b0c35c29', 'SPT0071', 'Rodrigue Murwanashyaka', 'F', '2007-05-26', 'aea4518a-7edd-405e-a303-50bd84994245', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('ff2047af-3d3b-453b-905f-d84c02ff11b5', 'SPT0072', 'Tonny Isaro Mico', 'M', '2007-11-11', 'aea4518a-7edd-405e-a303-50bd84994245', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('5ac426cb-6f10-4e95-909d-c81750ff4dd4', 'SPT0073', 'Kyliann Faita Nyangui Kombila', 'M', '2006-11-17', 'aea4518a-7edd-405e-a303-50bd84994245', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('ca7b1171-3940-49c4-b40c-4521d78bcc5a', 'SPT0074', 'Umulisa Cynthia', 'F', '2009-02-23', 'aea4518a-7edd-405e-a303-50bd84994245', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('5384e8e7-4e78-4ed4-b133-401a5b593551', 'SPT0075', 'Mpundu Larry Joeffray', 'M', '2008-02-12', 'aea4518a-7edd-405e-a303-50bd84994245', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('320caeae-3718-49f8-a8be-26b1c5186bc0', 'SPT0076', 'Rubirira Olivier', 'F', '2009-11-20', 'aea4518a-7edd-405e-a303-50bd84994245', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('24a97d2f-d316-49a5-a323-2ffeb9bacafc', 'SPT0077', 'Fidele Nsengiyaremye', 'F', '2006-01-15', 'aea4518a-7edd-405e-a303-50bd84994245', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('5055692b-e025-4e44-8404-0e4e7ae9a846', 'SPT0078', 'Habiyakare William', 'F', '2007-08-13', 'aea4518a-7edd-405e-a303-50bd84994245', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('335e66cb-42f8-49d0-b281-cdd511a5134c', 'SPT0079', 'Uwamahoro Jeanine', 'M', '2006-07-01', 'aea4518a-7edd-405e-a303-50bd84994245', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('52c2db00-4c22-484f-a1c8-790b5fa19ad3', 'SPT0080', 'Muhawenimana Aline', 'F', '2006-01-13', 'aea4518a-7edd-405e-a303-50bd84994245', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('b9edb53d-81a6-4be1-a22c-ac54164fb01e', 'SPT0081', 'Beza Carine', 'F', '2007-01-26', 'a8a721fd-9545-402b-8cd7-4014e6e7246c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('612f5dfe-7d5c-40b0-837e-04a1993108fe', 'SPT0082', 'Uwase Cylia', 'F', '2008-10-09', 'a8a721fd-9545-402b-8cd7-4014e6e7246c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('7e515698-4374-421e-b427-7a1f80fc8dbb', 'SPT0083', 'Murari Edward', 'M', '2007-09-22', 'a8a721fd-9545-402b-8cd7-4014e6e7246c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('d95ba96a-f7c6-4bb8-9b2f-60c66b25b770', 'SPT0084', 'Landry Gasasira Shingiro Mugabe', 'M', '2006-02-02', 'a8a721fd-9545-402b-8cd7-4014e6e7246c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('7e35770e-19c2-4f51-b538-89ca89a4176c', 'SPT0085', 'Isimbi Nshuti Ladouce', 'M', '2009-09-23', 'a8a721fd-9545-402b-8cd7-4014e6e7246c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('a9a5c4aa-d272-4144-b7a7-8a1de4eaef8a', 'SPT0086', 'Mutsinzi Pascal', 'M', '2006-03-24', 'a8a721fd-9545-402b-8cd7-4014e6e7246c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('6dbabf16-8c5f-4be6-b8c4-6f7eaf47c7ff', 'SPT0087', 'Nyamou Thon Chol', 'M', '2009-04-18', 'a8a721fd-9545-402b-8cd7-4014e6e7246c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('dc2a11e6-1467-4dd9-97cf-ea5438572b98', 'SPT0088', 'Turatsinze  Sandrine Bonheur', 'F', '2008-06-16', 'a8a721fd-9545-402b-8cd7-4014e6e7246c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('e9fcac07-01db-4d56-b3f8-407f9ab212cc', 'SPT0089', 'Teta  Zoe', 'F', '2007-04-16', 'a8a721fd-9545-402b-8cd7-4014e6e7246c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('b4f3684d-75e8-4e40-b065-615684aa9862', 'SPT0090', 'Justin Mwiseneza', 'M', '2009-10-13', 'a8a721fd-9545-402b-8cd7-4014e6e7246c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('5ec37003-f3d8-49d2-a2a5-feddc61f9e12', 'SPT0091', 'Nshimiyimana Providence', 'F', '2007-07-23', 'a8a721fd-9545-402b-8cd7-4014e6e7246c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('f7d1e1a2-2ce2-4786-81cb-3fbdce7f7c29', 'SPT0092', 'Irankunda Amiel', 'F', '2006-04-26', 'a8a721fd-9545-402b-8cd7-4014e6e7246c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('42a379f5-2e88-45e9-ba1d-de8cdba01487', 'SPT0093', 'Mwiza Leslie', 'F', '2008-11-22', 'a8a721fd-9545-402b-8cd7-4014e6e7246c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('a81b3a73-f789-4bf5-97e8-419ba72b313a', 'SPT0094', 'Amani Mupenda', 'M', '2008-06-21', 'a8a721fd-9545-402b-8cd7-4014e6e7246c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('345b3602-12ea-4c31-a98b-9f9a67ff5f30', 'SPT0095', 'Prince Ishimwe', 'F', '2009-04-17', 'a8a721fd-9545-402b-8cd7-4014e6e7246c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('3693d000-03b9-4bf2-989d-8f2a307b0bbb', 'SPT0096', 'Chuol Loang Kueth Nhail', 'M', '2008-11-07', 'a8a721fd-9545-402b-8cd7-4014e6e7246c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('b8e7f565-980f-412a-865a-42d10979dcb1', 'SPT0097', 'Mariba Esther', 'F', '2008-06-26', 'a8a721fd-9545-402b-8cd7-4014e6e7246c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('a02842bf-8b19-4694-a2ff-4cc92e404781', 'SPT0098', 'Byamungu Muzigaba Leonardo Louange', 'M', '2007-03-12', 'a8a721fd-9545-402b-8cd7-4014e6e7246c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('c5f2ab66-2f87-429b-95bc-a25fa67b1a63', 'SPT0099', 'Ujeneza Juliette', 'F', '2007-05-17', 'a8a721fd-9545-402b-8cd7-4014e6e7246c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('96646d2a-c409-4927-9c40-5af828ebdc0e', 'SPT0100', 'Umuhire Sifa Dorcas', 'F', '2009-05-10', 'a8a721fd-9545-402b-8cd7-4014e6e7246c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1);

INSERT INTO students (id, student_code, name, gender, date_of_birth, class_id, school_id, is_active) VALUES
  ('cfe48d73-41fd-40ee-9b3f-6b1a7dbea2a0', 'SPT0101', 'Joshua Karemera', 'F', '2009-04-23', 'a8a721fd-9545-402b-8cd7-4014e6e7246c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('62eae26b-1658-4134-880f-8b5895e606ff', 'SPT0102', 'Niyomugabo Kwizera Pacifique', 'M', '2006-08-19', 'a8a721fd-9545-402b-8cd7-4014e6e7246c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('18de8849-7952-4d64-be1f-a8e5b37bde4b', 'SPT0103', 'Ineza Amissa Ange', 'F', '2006-05-10', 'a8a721fd-9545-402b-8cd7-4014e6e7246c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('aa3a19bb-f884-4d8f-8f7b-10bc34f452c8', 'SPT0104', 'Kamikazi , Hervine', 'M', '2007-01-10', 'a8a721fd-9545-402b-8cd7-4014e6e7246c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('eca794ed-fcb8-496b-9de8-fd3d4708dabd', 'SPT0105', 'Ndizeye  Florien', 'F', '2009-07-17', 'a8a721fd-9545-402b-8cd7-4014e6e7246c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('4ead8a5d-cebe-4968-8eaa-d4dfbb9b55d1', 'SPT0106', 'Murungi Sarah', 'M', '2009-12-13', 'a8a721fd-9545-402b-8cd7-4014e6e7246c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('5476a48c-a7ce-4c45-a992-585dc6f0dbfc', 'SPT0107', 'Niyonkuru David', 'M', '2006-11-15', 'a8a721fd-9545-402b-8cd7-4014e6e7246c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('e94cd60c-30df-4e5e-8ccf-cda58d1622f0', 'SPT0108', 'Agatesi Asher', 'M', '2008-08-16', 'a8a721fd-9545-402b-8cd7-4014e6e7246c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('3e361cd4-de12-4661-88ee-07a41dfc8e16', 'SPT0109', 'Manzi Fred', 'M', '2009-03-13', 'a8a721fd-9545-402b-8cd7-4014e6e7246c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('e5129142-ec6e-4a52-a856-82fa7c64e624', 'SPT0110', 'Widad Omar Saleh', 'M', '2009-09-14', 'a8a721fd-9545-402b-8cd7-4014e6e7246c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('28761992-906f-4a07-9b1f-2d38d44a2722', 'SPT0111', 'Manzi  Yvan', 'M', '2008-01-20', 'a8a721fd-9545-402b-8cd7-4014e6e7246c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('ebd3c059-6e88-42cf-804e-f4e9c927f950', 'SPT0112', 'Irafasha Gilbert', 'F', '2008-05-15', 'a8a721fd-9545-402b-8cd7-4014e6e7246c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('bcadb0da-581b-4fd2-b49b-f12e0b7090a9', 'SPT0113', 'Isheja  Shannon Manzi', 'F', '2009-11-19', 'a8a721fd-9545-402b-8cd7-4014e6e7246c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('c01e3680-38af-4dc1-804e-4b51faba7ac6', 'SPT0114', 'Aimee Mignone Ishimwe', 'F', '2006-10-03', 'a8a721fd-9545-402b-8cd7-4014e6e7246c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('9eed6da6-468b-44aa-abd8-cc96b725c55f', 'SPT0115', 'Rwabagabo Ronald', 'M', '2009-06-12', 'a8a721fd-9545-402b-8cd7-4014e6e7246c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('2e7e00e3-61a3-43b3-b493-1031127d68f7', 'SPT0116', 'Ndemezo Thomson', 'M', '2008-10-28', 'a8a721fd-9545-402b-8cd7-4014e6e7246c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('fb9abe3a-ceb4-4f40-ae54-487ff8a5bbc7', 'SPT0117', 'Nikuze Hirwa Bertin', 'F', '2006-06-12', 'a8a721fd-9545-402b-8cd7-4014e6e7246c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('bdaea0cc-f8e5-4ea6-9859-868e137bf4a8', 'SPT0118', 'Nezerwa Assia', 'F', '2007-02-15', 'a8a721fd-9545-402b-8cd7-4014e6e7246c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('fcb875d1-9974-4264-b340-a916a51bcd65', 'SPT0119', 'Deng Mangor Majok Mangor', 'M', '2007-03-02', 'a8a721fd-9545-402b-8cd7-4014e6e7246c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('029fb0fc-7c1e-42f7-b650-a9f67ed95f49', 'SPT0120', 'Kariza Justine', 'F', '2009-10-10', 'a8a721fd-9545-402b-8cd7-4014e6e7246c', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('c9bbf454-5718-4a42-9925-9807f0b2ec54', 'SPT0121', 'Ryan Mugisha', 'M', '2008-06-03', '4ccfccc6-b07c-4159-94df-eac73859c08d', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('a97b90be-c41c-493b-97ba-8411defe1133', 'SPT0122', 'Miyar Kuol Dau Minyiel', 'M', '2008-03-06', '4ccfccc6-b07c-4159-94df-eac73859c08d', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('50542a8a-db82-497a-995c-a779a16a745b', 'SPT0123', 'Junior Bayonga', 'M', '2008-07-23', '4ccfccc6-b07c-4159-94df-eac73859c08d', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('0b66a7d9-bb4b-4156-a8e8-6eecb8f9486d', 'SPT0124', 'Ngoga Jean Allen', 'F', '2006-08-19', '4ccfccc6-b07c-4159-94df-eac73859c08d', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('a893b772-abd2-4119-b75c-001798cdbfae', 'SPT0125', 'Manzi Aime  Serge', 'M', '2006-09-21', '4ccfccc6-b07c-4159-94df-eac73859c08d', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('ef61eb75-5e3f-4b25-9e2e-2c9fe117b59a', 'SPT0126', 'Bhayani Shazan Nazim', 'M', '2009-04-07', '4ccfccc6-b07c-4159-94df-eac73859c08d', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('3b9a6713-9f0a-483b-b59e-33b14c911205', 'SPT0127', 'Kevin Kagaba', 'M', '2006-08-04', '4ccfccc6-b07c-4159-94df-eac73859c08d', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('d21a2764-31bb-420d-b1e6-b8c0a50d74f9', 'SPT0128', 'Kwizera Didier', 'F', '2009-01-03', '4ccfccc6-b07c-4159-94df-eac73859c08d', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('000590eb-36ca-420b-9622-9397afa941f6', 'SPT0129', 'Priscilla Bukinanyana', 'F', '2006-01-24', '4ccfccc6-b07c-4159-94df-eac73859c08d', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('79f2d5dc-e357-4e92-8e56-6ebd2e9d2a40', 'SPT0130', 'Mukandayambaje Fillette', 'F', '2008-08-15', '4ccfccc6-b07c-4159-94df-eac73859c08d', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('7ed2ed4a-eb1c-48f3-9526-14ae07c6caf5', 'SPT0131', 'Mahmud Hassan Abdallah Wedathalla', 'M', '2008-07-18', '4ccfccc6-b07c-4159-94df-eac73859c08d', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('31f08d88-af8e-4c09-8e06-d86e51a434d5', 'SPT0132', 'Kur Aya Olai Ajak', 'M', '2006-04-17', '4ccfccc6-b07c-4159-94df-eac73859c08d', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('ed7839ff-700f-40a9-9bf1-1d33b33fcc0f', 'SPT0133', 'Rutayisire Mpore Benjamin', 'F', '2008-09-08', '4ccfccc6-b07c-4159-94df-eac73859c08d', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('dcd76193-a462-4d23-8b49-ce42b61d779f', 'SPT0134', 'Safi Yolanda', 'M', '2006-11-22', '4ccfccc6-b07c-4159-94df-eac73859c08d', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('ae904be1-4710-4eb0-8cba-6033c58aa4f9', 'SPT0135', 'Dikigou Koumba Monica Audrey Naomie', 'M', '2007-03-27', '4ccfccc6-b07c-4159-94df-eac73859c08d', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('102120bc-80de-4a0d-a54f-903402dc82b0', 'SPT0136', 'Irakoze  Sonia', 'F', '2007-05-12', '4ccfccc6-b07c-4159-94df-eac73859c08d', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('4efa2fcf-93f3-4974-a3f7-d5bb2c12a66b', 'SPT0137', 'Iradukunda Axcella', 'F', '2008-01-24', '4ccfccc6-b07c-4159-94df-eac73859c08d', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('ae3f439b-801e-4ac0-aedd-511b4ea0f145', 'SPT0138', 'Atak Machok  Deng', 'M', '2006-09-07', '4ccfccc6-b07c-4159-94df-eac73859c08d', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('d2a2cc59-0530-4ca8-a458-734cb9aa7a38', 'SPT0139', 'Moses Deer Mamer Marier', 'M', '2008-11-15', '4ccfccc6-b07c-4159-94df-eac73859c08d', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('acfc8a3f-347c-4531-ab15-16ec1fad52bb', 'SPT0140', 'Belyse Ntakirutimana', 'F', '2009-04-04', '4ccfccc6-b07c-4159-94df-eac73859c08d', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('db1ec7d2-b9bc-4c87-91cf-5fd58cee4ea7', 'SPT0141', 'Tahir Muhammed Tahir Kamil', 'M', '2009-08-24', '4ccfccc6-b07c-4159-94df-eac73859c08d', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('d611bf89-8566-4abd-8099-b3cbb701a543', 'SPT0142', 'Mugisha Benigne Alphonsine', 'F', '2009-12-14', '4ccfccc6-b07c-4159-94df-eac73859c08d', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('d1a74f0d-3847-455f-871a-159ec50fb6e3', 'SPT0143', 'Iribagiza Peninah', 'F', '2009-02-12', '4ccfccc6-b07c-4159-94df-eac73859c08d', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('de230f8d-f279-47e4-ba24-e8e78024060e', 'SPT0144', 'Wilson Ninsiima', 'M', '2007-02-21', '4ccfccc6-b07c-4159-94df-eac73859c08d', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('0485eb0f-abee-4904-ad56-c62a8ef5d1f6', 'SPT0145', 'Mariette Ishimwe', 'F', '2009-04-10', '4ccfccc6-b07c-4159-94df-eac73859c08d', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('97d6c8b2-b7de-4431-aa00-15a0be05a2d9', 'SPT0146', 'Mukiza Blaise', 'F', '2008-12-09', '4ccfccc6-b07c-4159-94df-eac73859c08d', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('61d90dcd-3530-4251-8c02-c1cf245e6ebf', 'SPT0147', 'Inema Nziza Olin', 'F', '2008-08-12', '4ccfccc6-b07c-4159-94df-eac73859c08d', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('94d09d6a-9777-4d00-8912-ec358234b135', 'SPT0148', 'Souvenir Dufitimana', 'M', '2008-04-26', '4ccfccc6-b07c-4159-94df-eac73859c08d', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('683fe80d-f1e4-4b7a-8c91-8c79bd4735ce', 'SPT0149', 'Jennifer Muhoza', 'M', '2006-01-01', '4ccfccc6-b07c-4159-94df-eac73859c08d', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('5a3c0802-fe28-46c4-acb1-12685fa9d757', 'SPT0150', 'Cyuzuzo Viviane', 'M', '2007-10-27', '4ccfccc6-b07c-4159-94df-eac73859c08d', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1);

INSERT INTO students (id, student_code, name, gender, date_of_birth, class_id, school_id, is_active) VALUES
  ('8da71b14-a6e9-4072-a874-5195f31b4a4c', 'SPT0151', 'Uwamahoro Peace', 'M', '2006-07-28', '4ccfccc6-b07c-4159-94df-eac73859c08d', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('6fbc7ee0-5d0d-4a15-a49c-b5c07a046430', 'SPT0152', 'Julius Ruterana', 'M', '2006-04-24', '4ccfccc6-b07c-4159-94df-eac73859c08d', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('eb6f8130-35ae-4d6b-bfd9-1003944a0a66', 'SPT0153', 'Igiraneza Ezra', 'F', '2009-04-20', '4ccfccc6-b07c-4159-94df-eac73859c08d', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('f41bb88b-798e-49fc-85e3-899a09d6b386', 'SPT0154', 'Gateka Chris', 'F', '2009-12-25', '4ccfccc6-b07c-4159-94df-eac73859c08d', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('0c849690-767f-4e87-b4d7-1277bffcf4dd', 'SPT0155', 'Umuhire Divine', 'F', '2007-05-11', '4ccfccc6-b07c-4159-94df-eac73859c08d', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('ad4f8460-336c-4102-88f9-2c1d93547f45', 'SPT0156', 'Uyisenga Denis', 'F', '2007-02-21', '4ccfccc6-b07c-4159-94df-eac73859c08d', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('3e7a9260-b8a9-477b-81fb-6b1cdd35542e', 'SPT0157', 'Mugoli Chibululanda Jordine', 'M', '2008-08-20', '4ccfccc6-b07c-4159-94df-eac73859c08d', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('d32b4d83-e129-4991-88b5-bc22dfc63237', 'SPT0158', 'Uwera Marie Colombe', 'F', '2009-03-13', '4ccfccc6-b07c-4159-94df-eac73859c08d', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('cce56a33-ebcc-4ffd-8fe7-569d362ac2dc', 'SPT0159', 'Longar Ayuel Longar', 'M', '2009-07-05', '4ccfccc6-b07c-4159-94df-eac73859c08d', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('8f715d25-38c1-4908-a6bc-5bd029935f85', 'SPT0160', 'Jackson Niyonshuti', 'M', '2007-01-27', '4ccfccc6-b07c-4159-94df-eac73859c08d', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('4ebe66c4-6063-49c3-b84b-73fbbe751731', 'SPT0161', 'Isimbi Utamuriza  Ange Carine', 'M', '2006-01-06', '8026f846-103a-4ff9-ba32-423b4e8896cd', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('fad8cc58-8e07-4d34-80ec-b58886bfeb30', 'SPT0162', 'Ishimwe  Jean Claude', 'F', '2006-06-26', '8026f846-103a-4ff9-ba32-423b4e8896cd', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('6dc53231-e349-4e41-934c-e8d238ce2c70', 'SPT0163', 'Gasana Arsene', 'F', '2009-05-18', '8026f846-103a-4ff9-ba32-423b4e8896cd', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('2734fa11-de06-4906-9818-b505f623973f', 'SPT0164', 'Beni Regis Nemeyabahizi', 'M', '2009-09-03', '8026f846-103a-4ff9-ba32-423b4e8896cd', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('5d31055a-444c-4d2b-ae7f-3b31bf9e3818', 'SPT0165', 'Patience Uwimana', 'F', '2008-07-28', '8026f846-103a-4ff9-ba32-423b4e8896cd', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('23878c26-2744-47e3-b9c8-d07e0cb1b232', 'SPT0166', 'Eric Karambizi', 'M', '2006-10-15', '8026f846-103a-4ff9-ba32-423b4e8896cd', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('7a8a84d5-f0b0-4aaa-abbc-3186363fd513', 'SPT0167', 'Mustapha  Abdulla Mohammed Abdulla', 'F', '2006-03-12', '8026f846-103a-4ff9-ba32-423b4e8896cd', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('a45494ca-7d7f-48eb-9cad-2fc25f216ec9', 'SPT0168', 'Kayitare Edwin', 'F', '2009-03-04', '8026f846-103a-4ff9-ba32-423b4e8896cd', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('0749e4f1-77e8-4734-8e11-3f7739027315', 'SPT0169', 'Muvunyi Brenda Juliette', 'M', '2007-09-09', '8026f846-103a-4ff9-ba32-423b4e8896cd', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('b82d56ea-aad0-4265-b133-7ca4555cc2a5', 'SPT0170', 'Malek Mapuor Kon Mawurnyin', 'M', '2008-02-23', '8026f846-103a-4ff9-ba32-423b4e8896cd', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('5febb60e-b68f-4296-99af-83cd649cc059', 'SPT0171', 'Naome Mbabazi', 'F', '2008-09-09', '8026f846-103a-4ff9-ba32-423b4e8896cd', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('3f9420bc-9ac6-498d-a56f-f823f8217e28', 'SPT0172', 'Tekjwok Pasquale Yohannes Yor', 'M', '2006-03-10', '8026f846-103a-4ff9-ba32-423b4e8896cd', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('1f6392ce-30ae-40dd-85c3-f74baceccbb7', 'SPT0173', 'Edou Obiang Ondolewis', 'M', '2008-08-08', '8026f846-103a-4ff9-ba32-423b4e8896cd', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('6dd1a0a4-2d8f-4caa-b369-b9f5142df301', 'SPT0174', 'Gucungurwa Heroine', 'F', '2009-05-24', '8026f846-103a-4ff9-ba32-423b4e8896cd', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('0c208f3e-378c-4bae-968f-ad0af0d75555', 'SPT0175', 'Uwase Aimee Dominique', 'F', '2008-03-21', '8026f846-103a-4ff9-ba32-423b4e8896cd', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('bc8c38a1-690e-4b55-b506-4a7ecacf557b', 'SPT0176', 'Ishimwe Rurangirwa Chris', 'F', '2006-09-22', '8026f846-103a-4ff9-ba32-423b4e8896cd', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('b0b6e780-5d1b-4f44-820d-507c7354ef27', 'SPT0177', 'Ishimwe Oreste', 'F', '2009-11-06', '8026f846-103a-4ff9-ba32-423b4e8896cd', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('d03ff4b7-41e2-451d-b8c9-0ff2774e3062', 'SPT0178', 'Muyizere Nelson', 'F', '2006-12-01', '8026f846-103a-4ff9-ba32-423b4e8896cd', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('0a57a1d0-cc68-495c-89a5-d560590ef9a0', 'SPT0179', 'Munyaneza Christian', 'F', '2009-11-13', '8026f846-103a-4ff9-ba32-423b4e8896cd', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('a5805d29-2141-49fc-a787-657a9f87b602', 'SPT0180', 'Umutoniwase Marie Claire', 'F', '2007-07-05', '8026f846-103a-4ff9-ba32-423b4e8896cd', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('9b934828-e5f3-4afa-b34f-89368b2c9b08', 'SPT0181', 'Moussa Tom Abdelkerim', 'F', '2006-05-26', '8026f846-103a-4ff9-ba32-423b4e8896cd', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('baa0a814-c01a-42df-8580-287aa54e9057', 'SPT0182', 'Djuma  Abedi Jerome', 'F', '2006-06-10', '8026f846-103a-4ff9-ba32-423b4e8896cd', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('d6d0bc85-dabd-4daf-831d-2d4d60d66d96', 'SPT0183', 'Uwamahoro Liliane', 'M', '2007-11-19', '8026f846-103a-4ff9-ba32-423b4e8896cd', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('c93f9099-92e0-49fa-a8ef-b6432cfa5a52', 'SPT0184', 'Muhinda Davis Sunday', 'F', '2009-04-18', '8026f846-103a-4ff9-ba32-423b4e8896cd', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('710b0ab4-f794-4075-a613-7ce4d301466c', 'SPT0185', 'Uwera  Deborah', 'F', '2008-11-13', '8026f846-103a-4ff9-ba32-423b4e8896cd', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('577a003e-5953-40c3-94c1-e51e59d41cb6', 'SPT0186', 'Mushimiyimana  Sumaya', 'F', '2006-03-22', '8026f846-103a-4ff9-ba32-423b4e8896cd', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('a112d46e-e094-4cdd-906e-e2f26d1b91dc', 'SPT0187', 'Alliance Turashimimana', 'F', '2006-02-17', '8026f846-103a-4ff9-ba32-423b4e8896cd', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('3f25c600-4c50-405a-a56c-5e3f32653794', 'SPT0188', 'Ater  Anei Deng Ater', 'M', '2006-03-10', '8026f846-103a-4ff9-ba32-423b4e8896cd', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('7701d91f-d8b2-4a39-8610-c45c68deff29', 'SPT0189', 'Umutoni Lydia', 'M', '2009-02-15', '8026f846-103a-4ff9-ba32-423b4e8896cd', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('74223fc7-48c4-437e-8b9a-24f793b739b0', 'SPT0190', 'Munyeshyaka Adalbert', 'F', '2008-10-05', '8026f846-103a-4ff9-ba32-423b4e8896cd', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('d7705f05-1822-447b-a045-0550c5f5da6f', 'SPT0191', 'Divin Mugisha', 'M', '2007-11-27', '8026f846-103a-4ff9-ba32-423b4e8896cd', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('5e3c0116-8b31-4bb9-bc61-e1c67364dc84', 'SPT0192', 'Nzabanita Alain  Pascal', 'F', '2007-08-26', '8026f846-103a-4ff9-ba32-423b4e8896cd', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('5314c3fc-5d96-4ec1-995d-214d73e552f0', 'SPT0193', 'Ngabo Lin Kevin', 'M', '2006-12-11', '8026f846-103a-4ff9-ba32-423b4e8896cd', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('72518c33-046b-4f00-b0a8-74d857785ae6', 'SPT0194', 'Shema  Jean Christian', 'F', '2007-12-14', '8026f846-103a-4ff9-ba32-423b4e8896cd', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('32d39467-471b-4508-9434-abd73b6fc46d', 'SPT0195', 'Ali Mohamed Osman Osman Omer', 'M', '2009-07-23', '8026f846-103a-4ff9-ba32-423b4e8896cd', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('ba05529f-a3ca-4ddc-9bdb-2fcbee81814a', 'SPT0196', 'Byiringiro Ben', 'M', '2009-01-07', '8026f846-103a-4ff9-ba32-423b4e8896cd', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('24ae8f63-b24c-42d6-910c-60c7054c45bd', 'SPT0197', 'Kamikazi Paula Guillaine', 'M', '2007-01-20', '8026f846-103a-4ff9-ba32-423b4e8896cd', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('7f202ea8-886e-4baf-885a-e8cddc1ffff0', 'SPT0198', 'Akimana Lorie Loriane', 'F', '2007-07-14', '8026f846-103a-4ff9-ba32-423b4e8896cd', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('5a57347e-c137-42b0-994a-e7c373f0bc45', 'SPT0199', 'Bizoza Prince', 'F', '2006-02-18', '8026f846-103a-4ff9-ba32-423b4e8896cd', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1),
  ('ff29e5c5-b041-48f8-8293-02017e747f06', 'SPT0200', 'Abdelrahman Tawfig Hassan Mohamed', 'M', '2007-09-28', '8026f846-103a-4ff9-ba32-423b4e8896cd', '379882db-953c-44f7-85d1-d13eb4a0fa31', 1);

-- ── STEP 5: IMPORTANT — regenerate QR hashes ─────────
-- After running this SQL, run the QR repair script to
-- generate proper HMAC-SHA256 hashes for all SPT students:
-- node src/scripts/repairQrHashes.js  (or equivalent)

COMMIT;

-- ── VERIFY ─────────────────────────────────────────────
SELECT sc.name, sc.code, COUNT(s.id) AS students
FROM schools sc
LEFT JOIN students s ON s.school_id = sc.id AND s.is_active = 1
GROUP BY sc.id
ORDER BY sc.code;