# A standalone home: alice on the edge channel, no machine above.
{ sven, ... }:
{
  sven.home.alice-laptop = {
    user = sven.user.alice;
    channel = sven.channel.edge;
    system = sven.system.x86_64-linux;
  };
}
