#!/bin/bash

usage()
{
    echo $(basename $0) " [device_name]"
}
if [ $# != 1 ]; then 
  usage
  exit 1
fi

device=$1

if [ x"$device" = x"" ];then
  echo "device is null"
  exit 1 
fi

if [ ! -e $device.bin ]; then
  blkparse -i $device -d $device.bin > /dev/null
fi

btt -i $device.bin -q $device.q2c_latency -l $device.d2c_latency -m seek_freq -s seek -B $device.offset > $device.btt.result

find . -name $device."blktrace.*" -exec rm -rf {} \;

filename="sys_iops_fp.dat"

echo "
set terminal pngcairo enhanced font 'arial,10' fontscale 1.0 size 800, 600  
set title \"$device IOPS\"
set xlabel \"time (second)\"
set ylabel \"IOPS\"
set output '${device}_iops.png'
plot \"$filename\" w lp pt 7 title \"IOPS\" 
set output
set terminal pngcairo
" | /usr/bin/gnuplot

filename="sys_mbps_fp.dat"

echo "
set terminal pngcairo enhanced font 'arial,10' fontscale 1.0 size 800, 600  
set title \"$device MBPS\"
set xlabel \"time (second)\"
set ylabel \"MBPS\"
set output '${device}_mbps.png'
plot \"$filename\" w lp pt 7 title \"MBPS\" 
set output
set terminal pngcairo
" | /usr/bin/gnuplot

filename=$(ls $device.q2c_latency*.dat)

echo "
set terminal pngcairo enhanced font 'arial,10' fontscale 1.0 size 800, 600  
set title \"$device q2c latency\"
set xlabel \"time (second)\"
set ylabel \"q2c latency\"
set output '${device}_q2c_latency.png'
plot \"$filename\" title \"latency\" 
set output
set terminal pngcairo
" | /usr/bin/gnuplot


filename=$(ls $device.d2c_latency*.dat)

echo "
set terminal pngcairo enhanced font 'arial,10' fontscale 1.0 size 800, 600  
set title \"$device d2c latency\"
set xlabel \"time (second)\"
set ylabel \"d2c latency\"
set output '${device}_d2c_latency.png'
plot \"$filename\" title \"latency\" 
set output
set terminal pngcairo
" | /usr/bin/gnuplot

filename=$(ls seek_freq*)

echo "
set terminal pngcairo enhanced font 'arial,10' fontscale 1.0 size 800, 600  
set title \"$device seek times\"
set xlabel \"time (second)\"
set ylabel \"seek times\"
set output '${device}_seek_freq.png'
plot \"$filename\" w lp pt 7 title \"IOPS\" 
set output
set terminal pngcairo
" | /usr/bin/gnuplot

filename=$(ls $device.offset*_c.dat)

awk '{print $1,$2,$3-$2}' $filename >${filename}.dat

echo "
set terminal pngcairo enhanced font 'arial,10' fontscale 1.0 size 800, 600  
set title \"$device Generate Block access\"
set xlabel \"Time (second)\"
set ylabel \"Block Number\"
set zlabel \"# Blocks Per IO\" rotate by 90
set xtics rotate by 60
set grid
set output '${device}_offset_pattern.png'
splot \"${filename}.dat\" u 1:2:3 w l ls 1 title \"Offset\" 
set output
set terminal pngcairo
" | /usr/bin/gnuplot

echo "
set terminal pngcairo enhanced font 'arial,10' fontscale 1.0 size 800, 600  
set title \"$device offset \"
set xlabel \"time (second)\"
set ylabel \"offset (# block)\"
set output '${device}_offset.png'
plot \"$filename\" u 1:2 w lp pt 7 title \"offset of device\" 
set output
set terminal pngcairo
" | /usr/bin/gnuplot

total_io=`awk '{print $3-$2}' ${device}.offset_*_c.dat |sort -k 1 |uniq -c | awk 'BEGIN {  totol=0;} {total += $1;}  END {print total}'`

awk '{print $3-$2}' ${device}.offset_*_r.dat |sort -k 1 |uniq -c |sort -nk 2 | awk -v total=$total_io '{print $2,$1*100.0/total}' > $device.iosize_r_freq.dat
awk '{print $3-$2}' ${device}.offset_*_w.dat |sort -k 1 |uniq -c |sort -nk 2 | awk -v total=$total_io '{print $2,$1*100.0/total}' > $device.iosize_w_freq.dat

cat ${device}.iosize_r_freq.dat ${device}.iosize_w_freq.dat |sort -nk 1 > ${device}.iosize_freq.dat
join -1 1 -2 1 -o 0,1.2,2.2 -e 0 -a1 -a2 $device.iosize_r_freq.dat $device.iosize_w_freq.dat > $device.iosize_freq.dat 2>/dev/null

echo "
set terminal pngcairo enhanced font 'arial,10' fontscale 1.0 size 800, 600  
set auto x   
set yrange [0:100] 
set ylabel \"% of Total I/O\"  
set xlabel \"I/O Size (sector)\"      
set title \"I/O Distribution by I/O Size \" 
set style histogram rowstacked  
set boxwidth 0.50 relative 
set style fill transparent solid 0.5 noborder 
set xtics rotate by -45   
set grid  
set ytics 5 
set output '${device}_iosize_hist.png' 
plot \"$device.iosize_freq.dat\"  u 2:xticlabels(1)  with boxes ti \"read\" , ''  using 3:xticlabels(1) with boxes ti \"write\" 
" | /usr/bin/gnuplot


find . -name "*.dat" -exec rm -rf {} \;