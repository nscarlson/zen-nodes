IPV4=$1

echo "we are in!"
echo "Stopping"
systemctl stop zend zentracker

echo "List contents of /home/zentacular/.zen"
ls -al /home/zentacular/.zen/blocks
ls -al /home/zentacular/.zen/chainstate

echo "Delete known_hosts"
rm ~/.ssh/known_hosts

echo "Secure-copy blocks and chainstate to ${IPV4}",
scp -r /home/zentacular/.zen/blocks root@${IPV4}:~/.zen/blocks > /dev/null
scp -r /home/zentacular/.zen/chainstate root@${IPV4}:~/.zen/chainstate > /dev/null

echo 'Restart zend and zentracker again'
systemctl start zend && sleep 8 && systemctl start zentracker
