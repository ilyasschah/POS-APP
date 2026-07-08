using FluentValidation;
using MediatR;
using Api.Helpers;
using Api.Repository;
using Api.Models;

namespace Api.Queries.UserQuery;

public class GetUserByIdQuery : IRequest<UserDto?>
{
    public int Id { get; set; }
    public int CompanyId { get; set; }

    public class GetUserByIdQueryHandler : IRequestHandler<GetUserByIdQuery, UserDto?>
    {
        private readonly UserRepository _repository;

        public GetUserByIdQueryHandler(UserRepository repository)
        {
            _repository = repository;
        }
        public async Task<UserDto?> Handle(GetUserByIdQuery request, CancellationToken cancellationToken)
        {
            var entity = await _repository.GetByIdAsync(request.Id, request.CompanyId);
            return entity == null ? null : MapperUser.MapToUserDto(entity);
        }
    }
    public class GetUserByIdQueryValidator : AbstractValidator<GetUserByIdQuery>
    {
        public GetUserByIdQueryValidator()
        {
            RuleFor(x => x.Id).GreaterThan(0).WithMessage("User ID must be valid.");
            RuleFor(x => x.CompanyId).GreaterThan(0).WithMessage("Company ID must be valid.");
        }
    }
}