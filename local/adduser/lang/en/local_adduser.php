<?php
defined('MOODLE_INTERNAL') || die();

$string['courses'] = 'Enrol in courses';
$string['courses_help'] = 'The user is enrolled in each course with the manual enrolment method and its default role (usually Student).';
$string['idnumbertaken'] = 'Another user already has this ID number.';
$string['pluginname'] = 'Add a new user';
$string['privacy:metadata'] = 'The Add user plugin stores no personal data; users and enrolments are saved by Moodle itself.';
$string['timeend'] = 'Enrolment ends';
$string['timeend_help'] = 'The user can access the chosen courses until this date. It defaults to 3 months from today.';
$string['timeendpast'] = 'The enrolment end date must be in the future.';
$string['usercreated'] = 'User {$a->name} created and enrolled in {$a->count} course(s).';
$string['welcomeemail'] = 'Hi {$a->firstname},

An account has been created for you on {$a->sitename}.

Username: {$a->username}
Password: {$a->password}
Sign in: {$a->loginurl}

Your courses (access until {$a->timeend}):
{$a->courses}

Regards,
{$a->sitename}';
$string['welcomefailed'] = 'The welcome email to {$a} could not be sent; give the user their login details yourself.';
$string['welcomesent'] = 'Welcome email with login details sent to {$a}.';
$string['welcomesubject'] = 'Your {$a->sitename} account';
