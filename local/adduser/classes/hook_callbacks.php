<?php
namespace local_adduser;

class hook_callbacks {
    /**
     * Sends Moodle's own "Add a new user" form (user/editadvanced.php?id=-1) to this plugin's page,
     * so every new user gets an ID number. Editing existing users is unchanged.
     */
    public static function before_http_headers(\core\hook\output\before_http_headers $hook): void {
        global $PAGE;
        if ($PAGE->has_set_url()
                && $PAGE->url->compare(new \moodle_url('/user/editadvanced.php'), URL_MATCH_BASE)
                && optional_param('id', 0, PARAM_INT) == -1) {
            redirect(new \moodle_url('/local/adduser/index.php'));
        }
    }
}
