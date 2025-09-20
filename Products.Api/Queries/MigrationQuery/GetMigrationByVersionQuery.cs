using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.MigrationQuery
{
    public class GetMigrationByVersionQuery : IRequest<MigrationDto?>
    {
        public string Version { get; set; } = default!;

        public class GetMigrationByVersionQueryHandler : IRequestHandler<GetMigrationByVersionQuery, MigrationDto?>
        {
            private readonly MigrationRepository _repository;

            public GetMigrationByVersionQueryHandler(MigrationRepository repository)
            {
                _repository = repository;
            }

            public async Task<MigrationDto?> Handle(GetMigrationByVersionQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetByVersionAsync(request.Version);
                return entity == null ? null : MapperMigration.MapToMigrationDto(entity);
            }
        }
    }
}
