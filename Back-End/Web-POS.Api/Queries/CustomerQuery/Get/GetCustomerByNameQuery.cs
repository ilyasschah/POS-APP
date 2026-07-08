using FluentValidation;
using MediatR;
using Api.Repository;
using Api.Helpers;
using Api.Models;

namespace Api.Queries.CustomerQuery.Get
{
    public class GetCustomerByNameQuery : IRequest<CustomerDto?>
    {
        public string Name { get; set; }
        public int CompanyId { get; set; }
        public class GetCustomerByNameQueryHandler : IRequestHandler<GetCustomerByNameQuery, CustomerDto?>
        {
            private readonly CustomerRepository _repository;

            public GetCustomerByNameQueryHandler(CustomerRepository repository)
            {
                _repository = repository;
            }

            public async Task<CustomerDto?> Handle(GetCustomerByNameQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetCustomerByNameAsync(request.Name, request.CompanyId);
                return entity == null ? null : MapperCustomer.MapToCustomer(entity);
            }
        }
    }
    public class GetCustomerByNameQueryValidator : AbstractValidator<GetCustomerByNameQuery>
    {
        public GetCustomerByNameQueryValidator()
        {
            RuleFor(x => x.Name).NotEmpty().WithMessage("Customer name must be valid.");
            RuleFor(x => x.CompanyId).GreaterThan(0).WithMessage("Company ID must be valid.");
        }
    }
}
