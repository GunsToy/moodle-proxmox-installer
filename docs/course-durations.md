# Course enrolment durations (live site)

Each course's default enrolment duration (*course > Participants > Enrolment methods > Manual enrolments > Default enrolment duration*). The Add user page uses it when **Enrolment ends** is left off.

Set on 2026-11-04: Class of Business courses 90 days (3 months), all others 30 days (1 month). "Before" is what each course had until then (0 = no end date).

| id | Short name | Course | Before | Days |
|---|---|---|---|---|
| 32 | COBCIS | Class of Business: Collective Investments | 90 | 90 |
| 33 | COBPFB | Class of Business: Pension Fund Benefits | 90 | 90 |
| 35 | COBSTCL | Class Of Business: Short Term Commercial Lines | 0 | 90 |
| 36 | COBLT | Class of Business: Long Term | 0 | 90 |
| 37 | COBSTPL | Class Of Business: Short Term Personal Lines | 0 | 90 |
| 38 | COBHSB | Class of Business: Health Service Benefits | 0 | 90 |
| 5 | FIC2024 | CPD Course: FICA and AML - 2024 Update | 90 | 30 |
| 6 | Cyber | CPD Course: Intro to Cybersecurity | 90 | 30 |
| 7 | CyberSafe | CPD Course: Cybersecurity outside of the Office | 90 | 30 |
| 8 | King IV | CPD Course: Intro to King IV | 90 | 30 |
| 9 | Ethics | CPD Course: Ethics and Compliance | 90 | 30 |
| 10 | FAISGCOC | CPD Course: FAIS General Code of Conduct | 90 | 30 |
| 11 | CPD ITO | CPD Course: Introduction to the Ombudsman | 90 | 30 |
| 12 | CPD SARB | CPD Course: South African Reserve Bank | 90 | 30 |
| 13 | CPD NCA | CPD Course: SA National Credit Act | 90 | 30 |
| 14 | CPD BAC | CPD Course: Background to Compliance | 90 | 30 |
| 15 | CPD TCF | CPD Course: Treating Customers Fairly | 90 | 30 |
| 16 | CPD TPA | CPD Course: The Prudential Authority | 90 | 30 |
| 18 | KI & CO | CPD Course: Duties of the KI and CO | 90 | 30 |
| 19 | CPD FIC RI | CPD Course: FIC and Reporting Institutions | 0 | 30 |
| 20 | CPD FIC AI | CPD Course: FIC and Accountable Institutions | 0 | 30 |
| 21 | Crypto | CPD Course: Intro to Cryptocurrency | 90 | 30 |
| 22 | CPD CIS | CPD Course: Collective Investments | 90 | 30 |
| 23 | CPD CAR | CPD Course: Compliance and Risk | 90 | 30 |
| 24 | CPD PFB | CPD: Pension Fund Benefits | 90 | 30 |
| 26 | CPD IFE | CPD: Introduction to the Financial Environment | 90 | 30 |
| 27 | CPD HSB | CPD Course: Health Service Benefits | 0 | 30 |
| 29 | CPD STCL | CPD Course: Short Term Commercial | 0 | 30 |
| 30 | CPD STPL | CPD Course: Short Term Personal | 0 | 30 |
| 31 | CPD LT | CPD Course: Long Term | 0 | 30 |
| 34 | CPD CPA | CPD Course: South African Consumer Protection Act | 90 | 30 |
| 39 | FTS FICA | Annual FICA Training | 0 | 30 |
| 40 | FTS FFP | FAIS, FICA and POPI | 90 | 30 |
| 41 | ALC_FAIS1 | Alcari FAIS1 Short-Term | 0 | 30 |
| 42 | OAC | Ostrich Avoidance | 90 | 30 |

## Changing one course

Easiest in Moodle: open the course's Manual enrolments settings and change **Default enrolment duration**. It only affects new enrolments; people already enrolled keep their end date.

From the shell inside the container (days × 86400 = seconds; here course 39 to 365 days):

```bash
mariadb moodle -e "UPDATE mdl_enrol SET enrolperiod=365*86400 WHERE enrol='manual' AND courseid=39"
runuser -u www-data -- php /var/www/moodle/admin/cli/purge_caches.php
```

Update the table above when you do.

## How it was set

```bash
mariadb moodle -e "UPDATE mdl_enrol e JOIN mdl_course c ON c.id=e.courseid SET e.enrolperiod=IF(c.shortname LIKE 'COB%',90,30)*86400 WHERE e.enrol='manual' AND c.id<>1"
runuser -u www-data -- php /var/www/moodle/admin/cli/purge_caches.php
```
