#!/usr/bin/env python

import os
import sys
import glob
import subprocess
import tempfile
import time
import psutil
from optparse import OptionParser
from datetime import datetime

class DoCommandTimedOut(RuntimeError):
    pass

class DoCommandError(RuntimeError):
    def __init__(self, stderr, errno=0, stdout=''):
        RuntimeError.__init__(self, stderr)
        self.errno, self.stdout, self.stderr = errno, stdout, stderr

    def __str__(self):
        return "DoCommandError: errno {} stdout '{}' stderr '{}'" \
               .format(self.errno, self.stdout, self.stderr)

def do_cmd(cmd, timeout=0, force=False):

    cmdstr = cmd.encode('utf-8')
    if timeout <= 0:
        p = subprocess.Popen([cmdstr],
                             stdout=subprocess.PIPE,
                             stderr=subprocess.PIPE,
                             shell=True,
                             close_fds=True)
        (output, err) = p.communicate()
    else:
        with tempfile.TemporaryFile('w+') as outfp:
            with tempfile.TemporaryFile('w+') as errfp:
                p = subprocess.Popen([cmdstr],
                                     stdout=outfp,
                                     stderr=errfp,
                                     shell=True,
                                     close_fds=True)
                while p.poll() is None:
                    t = min(timeout, 0.1)
                    time.sleep(t)
                    timeout -= t
                    if timeout <= 0:
                        proc = psutil.Process(p.pid)
                        for c in proc.children(recursive=True):
                            c.kill()
                        proc.kill()
                        if force:
                            return ""
                        else:
                            raise DoCommandTimedOut(
                                u"command '{}' timeout".format(cmd)
                            )

                outfp.flush()   # don't know if this is needed
                outfp.seek(0)
                output = outfp.read()
                errfp.flush()   # don't know if this is needed
                errfp.seek(0)
                err = errfp.read()

    # prevent UnicodeDecodeError if invalid char in error/output
    err_str = str(err, 'utf-8', 'ignore')
    out_str = str(output, 'utf-8', 'ignore')
    if p.returncode != 0:
        if force:
            return ""
        else:
            raise DoCommandError(err, p.returncode, output)

    return output

def get_btt_result(bttfile,outfile):
    with open(outfile, 'w') as f:
        bfile = open(bttfile, 'r+')
        lines = bfile.readlines()
        n_ = 0

        for line in lines:
            if line.find('Total System')>0:
               break
            elif len(line.strip())>0 :
                if '=' in line:
                    f.write("\n# {} \n".format(line[line.find('= ')+2:line.find(' =')]))
                    n_ = 0
                elif '-' in line :
                    if  n_ == 0 :
                        f.write(line.replace("|", ""))
                        n_ = 1
                else:
                    f.write(line.replace("|", ""))
            
def process_info(device):
    do_cmd("bash gen_png.sh {}".format(device))
    bttfile = "{}.btt.result".format(device)
    outfile = "{}.md".format(device)
    c_datetime = datetime.now().strftime("%Y%m%d_%H%M")
    pdffile = "{}.pdf".format(device+'_'+c_datetime)

    get_btt_result(bttfile, outfile)

    with open(outfile, 'a') as f:
        png_file = "{}_iops.png".format(device)
        f.write("\n# {} IOPS\n".format(device))
        f.write("![{} {}]({})".format(device, 'IOPS', png_file))
        f.write('\n')

        png_file = "{}_mbps.png".format(device)
        f.write("\n# {} MBPS\n".format(device))
        f.write("![{} {}]({})".format(device, 'MBPS', png_file))
        f.write('\n')

        png_file = "{}_iosize_hist.png".format(device)
        f.write("\n# {} # IO SIZE Historgram\n".format(device))
        f.write("![{} {}]({})".format(device, 'IO SIZE Historgram', png_file))
        f.write('\n')

        png_file = "{}_d2c_latency.png".format(device)
        f.write("\n# {} D2C Latency Distribution\n".format(device))
        f.write("![{} {}]({})".format(device, 'D2C', png_file))
        f.write('\n')

        png_file = "{}_q2c_latency.png".format(device)
        f.write("\n# {} Q2C Latency Distribution\n".format(device))
        f.write("![{} {}]({})".format(device, 'Q2C', png_file))
        f.write('\n')

        png_2d_file = "{}_offset.png".format(device)
        f.write("\n# Offset Pattern 2D\n".format(device))
        f.write("![{} {}]({})".format(device, 'offset 2d', png_2d_file))
        f.write('\n')

        png_3d_file = "{}_offset_pattern.png".format(device)
        f.write("\n# Offset Pattern 3D\n".format(device))
        f.write("![{} {}]({})".format(device, 'offset 3d', png_3d_file))
        f.write('\n')
    
        png_file = "{}_seek_freq.png".format(device)
        f.write("\n# {} # of seeks\n".format(device))
        f.write("![{} {}]({})".format(device, 'seek', png_file))
        f.write('\n')

    if os.path.isfile('/usr/bin/pandoc'):
        do_cmd('/usr/bin/pandoc -t beamer -o {} {}'.format(pdffile,outfile))

def main(argv=None):
    if argv == None:
        argv = sys.argv


    usage = "Usage: %prog [options]"
    parser = OptionParser(usage=usage)
    parser.add_option(
        "-d", "--device",
        dest="device",
        help="device which we try to analyze"
    )

    (options, args) = parser.parse_args()

    if options.device is None:
        print("You must specify the device you try to analyze")
        exit(1)

    target_files = glob.glob("./{}.bin".format(options.device))
    if len(target_files) == 0 :
        print("Pleace run blkmon.sh to get  {}.bin".format(options.device))
        exit(2)

    return process_info(options.device)

if __name__ == "__main__":
    sys.exit(main())
