name := "emvAcceptedHere"

lazy val root = (project in file(".")).enablePlugins(PlayJava, SbtWeb)

//scalaVersion := "2.10.4"
scalaVersion := "2.11.6"

version := "1.0-SNAPSHOT"

libraryDependencies ++= Seq(
  jdbc,
  "com.typesafe.play" %% "anorm" % "2.4.0",
  cache,
  evolutions,
  "postgresql" % "postgresql" % "9.1-901.jdbc4",
  "com.typesafe.play" %% "play-mailer" % "3.0.1"
  //"com.typesafe" %% "play-plugins-mailer" % "2.2.0"
)     

//play.Project.playScalaSettings

// Compile the project before generating Eclipse files, so that generated .scala or .class files for views and routes are present
EclipseKeys.preTasks := Seq(compile in Compile)

routesGenerator := InjectedRoutesGenerator

pipelineStages := Seq(rjs, digest, gzip)