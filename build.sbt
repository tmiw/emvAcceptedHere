name := "emvAcceptedHere"

version := "1.0-SNAPSHOT"

libraryDependencies ++= Seq(
  jdbc,
  anorm,
  cache,
  "postgresql" % "postgresql" % "9.1-901.jdbc4",
  "com.typesafe" %% "play-plugins-mailer" % "2.2.0"
)     

play.Project.playScalaSettings
