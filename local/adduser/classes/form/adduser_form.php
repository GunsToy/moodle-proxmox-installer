<?php
namespace local_adduser\form;

defined('MOODLE_INTERNAL') || die();
require_once($CFG->libdir . '/formslib.php');

class adduser_form extends \moodleform {
    protected function definition() {
        global $CFG;
        $mform = $this->_form;

        $mform->addElement('text', 'username', get_string('username'), ['size' => 20]);
        $mform->setType('username', PARAM_USERNAME);
        $mform->addRule('username', null, 'required', null, 'client');

        if (!empty($CFG->passwordpolicy)) {
            $mform->addElement('static', 'passwordpolicyinfo', '', print_password_policy());
        }
        $mform->addElement('passwordunmask', 'newpassword', get_string('newpassword'), ['size' => 20]);
        $mform->setType('newpassword', PARAM_RAW);
        $mform->addRule('newpassword', null, 'required', null, 'client');

        foreach (['firstname', 'lastname', 'email', 'idnumber'] as $field) {
            $mform->addElement('text', $field, get_string($field), ['size' => 30]);
            $mform->setType($field, $field === 'email' ? PARAM_RAW_TRIMMED : PARAM_NOTAGS);
            $mform->addRule($field, null, 'required', null, 'client');
        }

        $mform->addElement('course', 'courses', get_string('courses', 'local_adduser'), [
            'multiple' => true,
            'requiredcapabilities' => ['enrol/manual:enrol'],
        ]);
        $mform->addHelpButton('courses', 'courses', 'local_adduser');

        $this->add_action_buttons(true, get_string('createuser'));
    }

    public function validation($data, $files) {
        global $CFG, $DB;
        $errors = parent::validation($data, $files);
        $local = ['mnethostid' => $CFG->mnet_localhost_id];

        if ($DB->record_exists('user', ['username' => $data['username']] + $local)) {
            $errors['username'] = get_string('usernameexists');
        }

        $passworderror = '';
        if (!check_password_policy($data['newpassword'], $passworderror)) {
            $errors['newpassword'] = $passworderror;
        }

        if (!validate_email($data['email'])) {
            $errors['email'] = get_string('invalidemail');
        } else if (empty($CFG->allowaccountssameemail) && $DB->record_exists_select('user',
                $DB->sql_equal('email', ':email', false) . ' AND mnethostid = :mnethostid',
                ['email' => $data['email']] + $local)) {
            $errors['email'] = get_string('emailexists');
        }

        $idnumber = trim($data['idnumber']);
        if ($idnumber === '') {
            $errors['idnumber'] = get_string('required');
        } else if ($DB->record_exists('user', ['idnumber' => $idnumber])) {
            $errors['idnumber'] = get_string('idnumbertaken', 'local_adduser');
        }

        // The course picker only lists allowed courses, but the submitted ids come from the browser.
        foreach ($data['courses'] ?? [] as $courseid) {
            $context = \context_course::instance((int)$courseid, IGNORE_MISSING);
            if (!$context || !has_capability('enrol/manual:enrol', $context)) {
                $errors['courses'] = get_string('nopermissions', 'error', get_string('enrolusers', 'enrol'));
            }
        }
        return $errors;
    }
}
