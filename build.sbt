name := "emvAcceptedHere"

lazy val root = (project in file(".")).enablePlugins(PlayJava, SbtWeb)

//scalaVersion := "2.10.4"
scalaVersion := "2.12.4"

version := "1.0-SNAPSHOT"

libraryDependencies ++= Seq(
  jdbc,
  "com.typesafe.play" %% "anorm" % "2.5.3",
  cache,
  evolutions,
  "postgresql" % "postgresql" % "9.1-901.jdbc4",
  "com.h2database" % "h2" % "1.4.194",
  "com.typesafe.play" %% "play-mailer" % "6.0.1",
  "com.typesafe.play" %% "play-mailer-guice" % "6.0.1",
  //"com.typesafe" %% "play-plugins-mailer" % "2.2.0"
)     

//play.Project.playScalaSettings

// Compile the project before generating Eclipse files, so that generated .scala or .class files for views and routes are present
EclipseKeys.preTasks := Seq(compile in Compile)

routesGenerator := InjectedRoutesGenerator

pipelineStages := Seq(rjs, digest, gzip)

libraryDependencies += specs2 % Test
libraryDependencies += filters
libraryDependencies += guice

resolvers += "scalaz-bintray" at "https://dl.bintray.com/scalaz/releases"
