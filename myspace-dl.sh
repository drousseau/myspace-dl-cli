#!/bin/bash --
#Myspace music downloader v5.3
#Updated on Oct 29th 2011
echo "MySpace music downloader by http://360percents.com"

if [ -z "$1" ]; then
 echo "";echo "Usage: `basename $0` [USER (eg. eminem)]";echo "";exit
fi

type -P rtmpdump &>/dev/null || {
read -n1 -p "I need a program called rtmpdump, do you wan to install it now? (y/n) "
echo [[ $REPLY = [yY] ]] && sudo apt-get -qq -y install rtmpdump || { echo "You didn't answer yes, or installation failed. Install it manualy. Exiting...";}  >&2; exit 1; }

echo "[+] Requesting $1"
page=`wget -L "http://myspace.com/$1" --quiet --user-agent="Mozilla" -O -`
userid=`echo "$page" | grep '?userId' | sed -e 's/.*userId=//' -e 's/".*//' | head -n 1`
artistid=`echo "$page" | grep '&artid' | sed -e 's/.*artid=//' -e 's/&.*//' | head -n 1`
artistname=`echo "$page" | grep 'og:title' | sed -e 's/.*property="og:title" content="//' -e 's/".*//' | head -n 1`
if [ ! "$userid" ]; then
 echo "[-] Trying second method for userID"
 userid=`echo "$page" | grep 'UserId' | sed -e 's/.*UserId=//' | sed -e 's/&.*//g' | head -n 1`
fi
if [ ! "$userid" ]; then
 echo "[+] ERROR: userid is empty!";
 echo '[-] This is common when a change in MySpace occurs, or if this artists page is configured in a non usual way.';
 echo '[-] See http://360percents.com/posts/linux-myspace-music-downloader/ for more info.';
 exit 1;
fi
echo "[-] User ID:$userid"
echo "[-] Artist Name: $artistname"
echo "[+] Requesting XML playlist"
link="http://www.myspace.com/music/services/player?artistid=$userid&scssb=2&action=getSortedSongs"
xml=`wget --quiet -L $link --user-agent="Mozilla" -O -`
songs=`echo "$xml" | tr ">" "\n" | grep 'songId' | tr ' ' "\n" | grep 'songId' | cut -d '"' -f 2`
if [ ! "$songs" ]; then
 echo "[-] Trying second method for playlist xml."
 link="http://www.myspace.com/music/services/player?action=getArtistPlaylist&artistUserId=$userid&artistId=$userid"
 xml=`wget --quiet -L $link --user-agent="Mozilla" -O -`
 songs=`echo "$xml" | tr ">" "\n" | grep 'songId' | tr ' ' "\n" | grep 'songId' | cut -d '"' -f 2`
fi
songcount=$((`echo "$songs" | wc -l`))
if [ $((`echo "$songs" | wc -c`)) -lt "2" ]; then
 echo "[+] ERROR: no songs found at this url."
 echo "[-] Please submit bugs to: http://360percents.com/posts/linux-myspace-music-downloader/";exit
fi
echo "[+] Found $songcount songs."

for i in `seq 1 $songcount`
do
 songid=`echo "$songs" | sed -n "$i"p`
 link="http://www.myspace.com/music/services/player?songId=$songid&action=getSong&sample=0&ptype=4"
 songpage=`wget -L "$link" --quiet --user-agent="Mozilla" -O -`
 title=`echo "$songpage" | tr "<" "\n" | grep 'title' | tr ">" "\n" | grep -v 'title' | sed -e '/^$/d' | sort -u`
 rtmp=`echo "$songpage" | tr "<" "\n" | tr ">" "\n" | grep 'rtmp://' | uniq`
 if [ ! "$title" ]; then
  title="$i"  #use number if no title found
 fi
 echo "Downloading $title..."
 artistname=$(echo "$artistname" | sed -e 's%/%_%g')
 rtmpdump -l 2 -r "$rtmp" -o "$artistname - $title.flv" -q -W "http://lads.myspacecdn.com/videos/MSMusicPlayer.swf"
 if which ffmpeg >/dev/null; then
  echo "Converting $title to mp3..."
  ffmpeg -y -i "$artistname - $title.flv" -metadata TITLE="$title" -metadata ARTIST="$artistname" -acodec copy -f mp3 "$artistname - $title.mp3" > /dev/null 2>&1 && rm "$artistname - $title.flv"
 fi
done
