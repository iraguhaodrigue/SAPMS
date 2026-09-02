const db = require('./src/config/db');
const { v4: uuidv4 } = require('uuid');

const TERM = '9152d82b-2499-4ab7-ade7-80643324e95f';
const assignments = [
  // teacher, class, subject
  ['e3503fc8-24ec-4cb0-a46e-de777083abb4','aec968b4-2135-4d58-bc7b-983d35ffb8a3','69242730-52fa-4593-a93d-ad99092c331c'], // Nkurunziza GSFAK S1-A English
  ['027d7eb0-931b-4e93-a70c-58ddd1977934','9257b7f9-a5ac-44bc-8f78-e7f0eec32923','c7fdc4c2-e395-492b-804b-8c1c4033b2cb'], // Uwase StPaul S1-A Math
  ['24c3e653-00e9-49be-9608-0d90fc1592f2','a481232d-c825-4dd1-a546-891f97180a15','a6207b4f-691c-4497-aebd-3046030c3db0'], // Habimana EST L3-NIT IoT
];

(async () => {
  for (const [teacher, cls, subj] of assignments) {
    try {
      await db.query(
        'INSERT INTO class_subjects (id, class_id, subject_id, teacher_id, term_id) VALUES (?,?,?,?,?)',
        [uuidv4(), cls, subj, teacher, TERM]
      );
      console.log('Assigned teacher', teacher.slice(0,8), 'to class', cls.slice(0,8));
    } catch(e) {
      if (e.code === 'ER_DUP_ENTRY') {
        // slot taken — just point the existing assignment at our teacher
        await db.query(
          'UPDATE class_subjects SET teacher_id=? WHERE class_id=? AND subject_id=? AND term_id=?',
          [teacher, cls, subj, TERM]
        );
        console.log('Reassigned existing slot to teacher', teacher.slice(0,8));
      } else console.error('Error:', e.message);
    }
  }
  console.log('Done');
  process.exit();
})();
