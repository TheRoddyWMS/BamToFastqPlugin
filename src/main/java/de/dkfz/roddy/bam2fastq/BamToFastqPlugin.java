package de.dkfz.roddy.bam2fastq;
/*
 * Copyright (c) 2018 DKFZ - ODCF
 *
 * Distributed under the MIT License (license terms are at https://www.github.com/eilslabs/Roddy/LICENSE.txt).
 */

import de.dkfz.roddy.plugins.BasePlugin;

class BamToFastqPlugin extends BasePlugin {

    public static final String CURRENT_VERSION_STRING = "0.0.20";
    public static final String CURRENT_VERSION_BUILD_DATE = "Fri Apr 20 13:42:46 CEST 2018";

    @Override
    public String getVersionInfo() {
        return "Roddy plugin: " + this.getClass().getName() + ", V " + CURRENT_VERSION_STRING + " built at " + CURRENT_VERSION_BUILD_DATE;
    }
}
