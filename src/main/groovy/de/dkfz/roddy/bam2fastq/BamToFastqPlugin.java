/*
 * Copyright (c) 2018 DKFZ - ODCF
 *
 * Distributed under the MIT License (license terms are at https://github.com/TheRoddyWMS/BamToFastqPlugin/blob/master/LICENSE.txt).
 */
package de.dkfz.roddy.bam2fastq;

import de.dkfz.roddy.plugins.BasePlugin;

class BamToFastqPlugin extends BasePlugin {

    public static final String CURRENT_VERSION_STRING = "1.1.1";
    public static final String CURRENT_VERSION_BUILD_DATE = "Thu Nov 14 12:17:54 CET 2019";

    @Override
    public String getVersionInfo() {
        return "Roddy plugin: " + this.getClass().getName() + ", V " + CURRENT_VERSION_STRING + " built at " + CURRENT_VERSION_BUILD_DATE;
    }
}
