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
    $courselines = [];
    foreach ($courseids as $courseid) {
        $course = get_course($courseid);
        $instance = $DB->get_record('enrol',
            ['courseid' => $courseid, 'enrol' => 'manual', 'status' => ENROL_INSTANCE_ENABLED], '*', IGNORE_MULTIPLE);
        if (!$instance) {
            $instanceid = $manual->add_default_instance($course);
            $instance = $DB->get_record('enrol', ['id' => $instanceid], '*', MUST_EXIST);
        }
        $timestart = time();
        // A picked date wins; otherwise the course's default duration, and 0 (no end) if it has none.
        $timeend = $data->timeend ?: ($instance->enrolperiod ? $timestart + $instance->enrolperiod : 0);
        $manual->enrol_user($instance, $user->id, $instance->roleid, $timestart, $timeend);
        $courselines[] = get_string('courseline', 'local_adduser', (object)[
            'name' => format_string($course->fullname, true, ['context' => context_course::instance($courseid)]),
            'until' => $timeend ? userdate($timeend, get_string('strftimedate', 'langconfig')) : get_string('noend', 'local_adduser'),
            'url' => (new moodle_url('/course/view.php', ['id' => $courseid]))->out(false),
        ]);
    }
    $transaction->allow_commit();

    // Sent after commit, so a rolled-back user never gets login details.
    $a = (object)[
        'firstname' => $data->firstname,
        'sitename' => format_string($SITE->fullname),
        'username' => $data->username,
        'password' => $data->newpassword,
        'loginurl' => (new moodle_url('/login/index.php'))->out(false),
        'courses' => $courselines ? implode("\n", $courselines) : get_string('none'),
    ];
    $sent = email_to_user(core_user::get_user($user->id), core_user::get_noreply_user(),
        get_string('welcomesubject', 'local_adduser', $a), get_string('welcomeemail', 'local_adduser', $a));

    $message = get_string('usercreated', 'local_adduser', ['name' => fullname($user), 'count' => count($courseids)]) . ' ' .
        get_string($sent ? 'welcomesent' : 'welcomefailed', 'local_adduser', $data->email);
    redirect(new moodle_url('/user/profile.php', ['id' => $user->id]), $message, null,
        $sent ? \core\output\notification::NOTIFY_SUCCESS : \core\output\notification::NOTIFY_WARNING);
}

echo $OUTPUT->header();
$form->display();
echo $OUTPUT->footer();
