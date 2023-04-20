FROM 623491699425.dkr.ecr.us-west-2.amazonaws.com/cruddur-python:3.10-slim-buster

#Set working directory to backend-flask inside container
WORKDIR /backend-flask

#Copy requirements.txt from current directory to container 
COPY requirements.txt requirements.txt

#Install flask and flask cor from Python package manager
RUN pip3 install -r requirements.txt

#Copies all file in current working directory to directory set by WORKDIR
COPY . .

#Set port for inter-container communication
EXPOSE ${PORT}

#Excutes a command 
CMD [ "python3", "-m" ,"-u", "flask", "run", "--host=0.0.0.0", "--port=4567", "--debug"]