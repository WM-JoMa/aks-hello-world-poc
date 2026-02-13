FROM openjdk:17
COPY hello-world.java /usr/src/myapp/hello-world.java
WORKDIR /usr/src/myapp
RUN javac hello-world.java
CMD ["java", "HelloWorld"]