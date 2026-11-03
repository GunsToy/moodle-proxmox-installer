<?php
// Add a new user with a required ID number and enrol them in several courses at once.
require(__DIR__ . '/../../config.php');
require_once($CFG->dirroot . '/user/lib.php');

$context = context_system::instance();
require_login();
require_capability('moodle/user:create', $context);

$url = new moodle_url('/local/adduser/index.php');
$PAGE->set_context($context);
$PAGE->set_url($url);
$PAGE->set_pagelayout('admin');
$PAGE->set_title(get_string('pluginname', 'local_adduser'));
$PAGE->set_heading(get_string('pluginname', 'local_adduser'));

$form = new \local_adduser\form\adduser_form($url);
if ($form->is_cancelled()) {
    redirect(new moodle_url('/admin/user.php'));
}

if ($data = $form->get_data()) {
    // One transaction: if any enrolment fails, the user is not created either.
    $transaction = $DB->start_delegated_transaction();
    $user = (object)[
        'auth' => 'manual',
        'confirmed' => 1,
        'mnethostid' => $CFG->mnet_localhost_id,
        'username' => $data->username,
        'password' => $data->newpassword,
        'firstname' => $data->firstname,
        'lastname' => $data->lastname,
        'email' => $data->email,
        'idnumber' => trim($data->idnumber),
    ];
    $user->id = user_create_user($user);

    $manual = enrol_get_plugin('manual');
    $courseids = $data->courses ?? [];
    foreach ($courseids as $courseid) {
        $instance = $DB->get_record('enrol',
            ['courseid' => $courseid, 'enrol' => 'manual', 'status' => ENROL_INSTANCE_ENABLED], '*', IGNORE_MULTIPLE);
        if (!$instance) {
            $instanceid = $manual->add_default_instance(get_course($courseid));
            $instance = $DB->get_record('enrol', ['id' => $instanceid], '*', MUST_EXIST);
        }
        $manual->enrol_user($instance, $user->id, $instance->roleid, time(), $data->timeend);
    }
    $transaction->allow_commit();

    redirect(new moodle_url('/user/profile.php', ['id' => $user->id]),
        get_string('usercreated', 'local_adduser', ['name' => fullname($user), 'count' => count($courseids)]),
        null, \core\output\notification::NOTIFY_SUCCESS);
}

echo $OUTPUT->header();
$form->display();
echo $OUTPUT->footer();
