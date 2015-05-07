name := "emvAcceptedHere"

lazy val root = (project in file(".")).enablePlugins(PlayJava, SbtWeb)

//scalaVersion := "2.10.4"
scalaVersion := "2.11.6"

version := "1.0-SNAPSHOT"

libraryDependencies ++= Seq(
  jdbc,
  anorm,
  cache,
  "postgresql" % "postgresql" % "9.1-901.jdbc4",
  "com.typesafe.play" %% "play-mailer" % "2.4.0"
  //"com.typesafe" %% "play-plugins-mailer" % "2.2.0"
)     

//play.Project.playScalaSettings
