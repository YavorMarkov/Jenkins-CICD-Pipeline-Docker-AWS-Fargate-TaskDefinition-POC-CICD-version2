# init a base image (Alpine is small Linux distro)
# FROM python:3.6.1-alpine 
FROM python:alpine3.16

# update pip to minimize dependency errors
RUN pip install --upgrade pip

# define the present working directory
WORKDIR /web-flask

# copy the contents into the working dir
ADD . /web-flask
  

# run pip to install the dependencies of the flask app
RUN pip install -r requirements.txt

#RUN apk add doas за домашно
#RUN useradd user1 && chown user1:user1 webapp.py && chmod 500 webapp.py RUN apk add doas;
RUN apk update && apk add shadow

# Create a new user
RUN adduser -D -u 1000 user1


USER user1 

# define the command to start the container
CMD ["python","webapp.py"]

