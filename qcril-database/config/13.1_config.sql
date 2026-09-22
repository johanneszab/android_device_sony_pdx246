/*
  SPDX-FileCopyrightText: The LineageOS Project
  SPDX-FileCopyrightText: Johannes Meyer zum Alten Borgloh
  SPDX-License-Identifier: Apache-2.0
*/

/*
  Sony's database enables persist.vendor.radio.poweron_opt. With it, and the
  screen off, qcril parks every incoming SMS and notifies Qualcomm's own
  telephony framework through an OEM hook instead of sending
  RIL_UNSOL_RESPONSE_NEW_SMS. LineageOS has no receiver for that hook, so after
  20 s qcril drops the SMS unacknowledged and the network holds every later
  one. Same fix as device/sony/pdx257 (0015.1_config.sql).

  The version bump to 13.1 makes qcril run this script on devices that
  already have a 13.0 database in /data/vendor/radio.
*/

CREATE TABLE IF NOT EXISTS qcril_properties_table (property TEXT PRIMARY KEY NOT NULL, def_val TEXT, value TEXT);
INSERT OR REPLACE INTO qcril_properties_table(property, def_val) VALUES('qcrildb_version',13.1);
UPDATE qcril_properties_table SET def_val="0" WHERE property="persist.vendor.radio.poweron_opt";
