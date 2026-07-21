import React from 'react';
import { Link } from 'react-router-dom';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { ChevronDown } from 'lucide-react';
import { businessLinks } from '@/config/businessLinks';
import { slackInstallUrl } from '@/lib/slack';

export const BusinessMenu: React.FC = () => {
  return (
    <DropdownMenu>
      <DropdownMenuTrigger className="flex items-center gap-1 text-gray-600 hover:text-gray-900 transition font-medium text-base outline-none">
        Business
        <ChevronDown className="w-4 h-4" />
      </DropdownMenuTrigger>
      <DropdownMenuContent className="w-[360px] p-3" align="start">
        <div className="flex flex-col gap-1">
          {businessLinks.map(link => (
            <DropdownMenuItem key={link.id} asChild className="p-0 focus:bg-transparent">
              <Link
                to={link.route}
                className="flex items-start gap-3 p-3 rounded-lg hover:bg-gray-50 transition-colors cursor-pointer"
              >
                <div
                  className={`shrink-0 flex items-center justify-center w-10 h-10 rounded-lg bg-gradient-to-br ${link.gradient}`}
                >
                  <link.icon className="w-5 h-5 text-white" />
                </div>
                <div>
                  <div className="font-semibold text-gray-900 text-sm">{link.label}</div>
                  <div className="text-xs text-gray-500 mt-0.5 leading-snug">
                    {link.description}
                  </div>
                </div>
              </Link>
            </DropdownMenuItem>
          ))}
        </div>
        <div className="mt-2 pt-3 border-t border-gray-200 flex justify-center">
          <a href={slackInstallUrl()} aria-label="Add CardJoy to Slack">
            <img
              alt="Add to Slack"
              height="40"
              width="139"
              src="https://platform.slack-edge.com/img/add_to_slack.png"
              srcSet="https://platform.slack-edge.com/img/add_to_slack.png 1x, https://platform.slack-edge.com/img/add_to_slack@2x.png 2x"
            />
          </a>
        </div>
      </DropdownMenuContent>
    </DropdownMenu>
  );
};
