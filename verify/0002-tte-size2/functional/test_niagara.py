#!/usr/bin/env python3
#
# Functional test that boots OpenSolaris on the sun4v niagara machine
# and checks that the kernel comes up.
#
# Copyright (c) 2026 Dmitry Pimenov
#
# SPDX-License-Identifier: GPL-2.0-or-later

import os
import shutil

from qemu_test import QemuSystemTest, Asset
from qemu_test import wait_for_console_pattern
from qemu_test import exec_command_and_wait_for_pattern


class NiagaraMachine(QemuSystemTest):
    """
    Boots the OpenSolaris snv_134 automated-install image on -M niagara.

    The machine has no firmware in-tree. OpenBoot, the hypervisor, the
    reset vector and the NVRAM image come from the OpenSPARC T1 archive
    that docs/system/target-sparc64.rst points at (S10image/, BSD+
    licensed per the hypervisor/obp source headers in the same archive).
    The machine description and hypervisor config are built from source
    with mdgen; the archive's own MD has no memory->mblock arcs and this
    kernel panics in lgrp_traverse() on it.

    With 4G of RAM the kernel maps its kmem64 nucleus with a 256M page,
    which exercises the 3-bit TTE page-size field: without Size<2>
    (bit 48) the entry is installed as 64k and the boot hangs after
    loading unix.
    """

    ASSET_T1_ARCHIVE = Asset(
        ('http://download.oracle.com/technetwork/systems/opensparc/'
         'OpenSPARCT1_Arch.1.5.tar.bz2'),
        '833b086196e29eca296dd4722b1a2e853c2c8228634106ce71d59b48192518e9')

    MD_URL = ('https://raw.githubusercontent.com/unix0cc/md/'
              '4fa9b7b0793db67d32426eb23f3a9324f3edf74a/'
              'bin/pagesize_256m/4096/')
    ASSET_MD = Asset(MD_URL + '1up-md.bin',
        '11c18ef2b054cb7bb48824e421b138517eaad0d459c38dd0cc7dc63d05019a20')
    ASSET_HV = Asset(MD_URL + '1up-hv.bin',
        '9df4cf283410633ca0e822cd846a652fea4e59a8f452235490c2fcae9dd296c5')

    ASSET_ISO = Asset(
        ('https://mirror.math.princeton.edu/pub/openindiana-iso/archive/'
         'opensolaris/osol-dev-134-ai-sparc.iso'),
        'fe36ae8d3aea3797a10607c0e024c02fe91f99f43f64e5234280b7a0c4e8ab0a')

    def test_sparc64_niagara_snv134(self):
        self.set_machine('niagara')

        # niagara loads six fixed file names from -L; put them in one dir
        fw_dir = self.scratch_file('fw')
        for member in ('openboot.bin', 'q.bin', 'reset.bin', 'nvram1'):
            self.archive_extract(self.ASSET_T1_ARCHIVE,
                                 member='./S10image/' + member)
        shutil.copytree(self.scratch_file('S10image'), fw_dir)
        # assets are cached under their hash; niagara needs the real names
        shutil.copy(self.ASSET_MD.fetch(), os.path.join(fw_dir, '1up-md.bin'))
        shutil.copy(self.ASSET_HV.fetch(), os.path.join(fw_dir, '1up-hv.bin'))

        self.vm.set_console()
        self.vm.add_args('-m', '4096',
                         '-L', fw_dir,
                         '-drive', 'if=pflash,readonly=on,file='
                                   + self.ASSET_ISO.fetch())
        self.vm.launch()
        wait_for_console_pattern(self, 'ok ')
        exec_command_and_wait_for_pattern(self, 'boot',
            'SunOS Release 5.11 Version snv_134')
        # the AI image has no console-login service; this is as far as
        # its boot goes
        wait_for_console_pattern(self,
            'Enter user name for system maintenance',
            failure_message='panic')


if __name__ == '__main__':
    QemuSystemTest.main()
