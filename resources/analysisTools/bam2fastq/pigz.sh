#!/usr/bin/env bash

pigz -p "${compressorThreads:-1}" -c "$@"
