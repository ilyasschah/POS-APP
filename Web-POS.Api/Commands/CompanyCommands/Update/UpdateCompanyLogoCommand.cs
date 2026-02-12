using FluentValidation;
using MediatR;
using Products.Api.Models;
using Products.Api.Services;

namespace Products.Api.Commands.CompanyCommands.Update
{
    public class UpdateCompanyLogoCommand : IRequest<bool>
    {
        public UpdateCompanyLogoRequest Request { get; set; }
        public UpdateCompanyLogoCommand(UpdateCompanyLogoRequest request)
        {
            Request = request;
        }
        public class UpdateCompanyLogoCommandHandler : IRequestHandler<UpdateCompanyLogoCommand, bool>
        {
            private readonly CompanyService _service;
            public UpdateCompanyLogoCommandHandler(CompanyService service)
            {
                _service = service;
            }
            public async Task<bool> Handle(UpdateCompanyLogoCommand request, CancellationToken cancellationToken)
            {
                var result = await _service.Update_LogoAsync(request.Request);
                return result;
            }
        }
        public class UpdateCompanyLogoCommandValidator : AbstractValidator<UpdateCompanyLogoCommand>
        {
            public UpdateCompanyLogoCommandValidator()
            {
                RuleFor(c => c.Request.Id).NotNull().NotEmpty().WithMessage("Id must not be empty.");
                RuleFor(c => c.Request.Logo).NotNull().NotEmpty().WithMessage("LogoBase64 must not be empty.");
            }
        }
    }
}
