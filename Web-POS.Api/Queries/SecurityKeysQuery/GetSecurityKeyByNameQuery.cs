using Api.Models;
using Api.Services;
using FluentValidation;
using MediatR;

namespace Api.Queries.SecurityKeyQueries
{
    public class GetSecurityKeyByNameQuery : IRequest<SecurityKeyDto?>
    {
        public required string Name { get; set; }
        public required int CompanyId { get; set; }
    }
    public class GetSecurityKeyByNameHandler : IRequestHandler<GetSecurityKeyByNameQuery, SecurityKeyDto?>
    {
        private readonly SecurityKeyService _service;

        public GetSecurityKeyByNameHandler(SecurityKeyService service)
        {
            _service = service;
        }

        public async Task<SecurityKeyDto?> Handle(GetSecurityKeyByNameQuery request, CancellationToken cancellationToken)
        {
            return await _service.GetByNameAsync(request.Name, request.CompanyId);
        }
    }
    public class GetSecurityKeyByNameValidator : AbstractValidator<GetSecurityKeyByNameQuery>
    {
        public GetSecurityKeyByNameValidator()
        {
            RuleFor(q => q.Name).NotEmpty().WithMessage("Name is required.");
            RuleFor(q => q.CompanyId).GreaterThan(0).WithMessage("Company ID must be greater than 0.");
        }
    }
}