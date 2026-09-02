const bcrypt = require('bcryptjs');
const db = require('./src/config/db');
const { v4: uuidv4 } = require('uuid');

const GSFAK = 'e099eb00-62c6-43bd-8c9f-27131b4dacf5';
const EST   = '8b5c6cf4-d82c-46af-891e-97868b09f27e';
const SPT   = '379882db-953c-44f7-85d1-d13eb4a0fa31';

async function run() {
  const h = async (p) => bcrypt.hash(p, 10);

  const accounts = [
    { id: uuidv4(), name: 'System Administrator',
      email: 'sysadmin@sapms.rw',
      password: await h('Sysadmin@2025'), role: 'sysadmin', school_id: null },

    { id: uuidv4(), name: 'Gilbert Uwase',
      email: 'admin.ns-gsfak@sapms.rw',
      password: await h('Admin@123'), role: 'admin', school_id: GSFAK },

    { id: uuidv4(), name: 'Alexis Sibomana',
      email: 'admin.ns-est@sapms.rw',
      password: await h('Admin@123'), role: 'admin', school_id: EST },

    { id: uuidv4(), name: 'Jean Paul Nzeyimana',
      email: 'admin.ns-spt@sapms.rw',
      password: await h('Admin@123'), role: 'admin', school_id: SPT },

    { id: uuidv4(), name: 'Jean Pierre Habimana',
      email: 'habimana.jp@sapms.rw',
      password: await h('Teacher@2025'), role: 'teacher', school_id: EST },

    { id: uuidv4(), name: 'Marie Claire Uwase',
      email: 'uwase.mc@sapms.rw',
      password: await h('Teacher@2025'), role: 'teacher', school_id: SPT },

    { id: uuidv4(), name: 'Patrick Nkurunziza',
      email: 'nkurunziza.p@sapms.rw',
      password: await h('Teacher@2025'), role: 'teacher', school_id: GSFAK },
  ];

  for (const a of accounts) {
    try {
      await db.query(
        `INSERT INTO users (id, name, email, password, role, school_id)
         VALUES (?,?,?,?,?,?)
         ON DUPLICATE KEY UPDATE
           name=VALUES(name), password=VALUES(password),
           role=VALUES(role), school_id=VALUES(school_id)`,
        [a.id, a.name, a.email, a.password, a.role, a.school_id]
      );
      console.log('OK:', a.role.padEnd(10), a.email);
    } catch(e) {
      console.error('FAIL:', a.email, e.message);
    }
  }
  console.log('\nAll done.');
  process.exit();
}
run();
