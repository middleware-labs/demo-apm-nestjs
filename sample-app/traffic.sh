while true; do 
  for i in {1..10}; do 
    curl -s http://localhost:3000/cpu > /dev/null & 
    curl -s http://localhost:3000/ > /dev/null & 
    curl -s http://localhost:3000/docs > /dev/null & 
    curl -s http://localhost:3000/ping > /dev/null & 

    # echo "yes"
  done; 
  sleep 1; 
done