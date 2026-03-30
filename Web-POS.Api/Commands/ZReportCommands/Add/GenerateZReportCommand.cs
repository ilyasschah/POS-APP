using FluentValidation;
using MediatR;
using Api.Models;
using Api.Services;

namespace Api.Commands.ZReportCommands
{
    public class GenerateZReportCommand : IRequest<ZReportDto>
    {
        public int CompanyId { get; set; }
        public int UserId { get; set; }

        public GenerateZReportCommand(int companyId, int userId)
        {
            CompanyId = companyId;
            UserId = userId;
        }

        public class GenerateZReportCommandHandler : IRequestHandler<GenerateZReportCommand, ZReportDto>
        {
            private readonly ZReportService _service;

            public GenerateZReportCommandHandler(ZReportService service)
            {
                _service = service;
            }

            public async Task<ZReportDto> Handle(GenerateZReportCommand request, CancellationToken cancellationToken)
            {
                return await _service.GenerateZReportAsync(request.CompanyId, request.UserId);
            }
        }

        public class GenerateZReportCommandValidator : AbstractValidator<GenerateZReportCommand>
        {
            public GenerateZReportCommandValidator()
            {
                RuleFor(x => x.CompanyId).GreaterThan(0);
                RuleFor(x => x.UserId).GreaterThan(0);
            }
        }
    }
}